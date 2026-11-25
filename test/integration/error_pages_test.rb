require "test_helper"
require "minitest/mock"

# The branded error pages. In the test environment DebugExceptions would answer
# before config.exceptions_app is ever consulted (consider_all_requests_local),
# so these tests switch the request env to production-style handling
# (show_exceptions = :all, no detailed exceptions) to drive the real middleware
# stack -> ErrorsController path.
class ErrorPagesTest < ActionDispatch::IntegrationTest
  BROWSER = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15" }.freeze

  setup do
    cfg = Rails.application.env_config
    @saved = cfg.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    cfg["action_dispatch.show_exceptions"] = :all
    cfg["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config.merge!(@saved)
  end

  # A request env like the one ShowExceptions hands the exceptions app (the
  # application's env_config supplies cookies/session/key generator).
  def error_env(path)
    Rails.application.env_config.merge(Rack::MockRequest.env_for(path, "HTTP_USER_AGENT" => BROWSER["User-Agent"])).tap do |env|
      env["action_dispatch.exception"] = StandardError.new("x")
    end
  end

  def robots_meta = css_select("meta[name=robots]").map { |m| m["content"] }

  def assert_branded_404
    assert_response :not_found
    assert_equal "text/html", response.media_type
    assert_select "h1", text: /couldn.t find that page/i
    assert_select "nav[aria-label=Primary] a.nav-link", text: "Survivors"       # the site layout
    assert_select "footer, .footer, a[data-action=manage-privacy]"               # ...and its footer
    assert_equal [ "noindex, nofollow" ], robots_meta
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_empty css_select("link[rel=canonical]"), "error pages must not declare a canonical URL"
    assert_empty css_select("meta[name=google-adsense-account]"), "no ads on error pages"
  end

  test "an unknown URL renders the branded 404 with the 404 status" do
    get "/no/such/page"
    assert_branded_404
  end

  test "the 404 page has a survivor search box and popular links" do
    get "/no/such/page"
    assert_select "form[action='#{survivors_path}'][method=get] input[name=q]"
    %w[/survivors /episodes /items /locations /shop /seasons].each do |href|
      assert_select "main a[href='#{href}']", { minimum: 1 }, "missing popular link #{href}"
    end
    assert_select "a", text: /Where to Watch/
    assert_select "a[href='/']", text: /homepage/i
  end

  test "the forum link appears only when the forum is open" do
    get "/no/such/page"
    assert_select "#content a[href='/forum']", 0

    ENV["FORUM_ENABLED"] = "true"
    get "/no/such/page"
    assert_select "#content a[href='/forum']", minimum: 1
  ensure
    ENV["FORUM_ENABLED"] = nil
  end

  test "a record that does not exist is a branded 404" do
    get "/survivors/no-such-person"
    assert_branded_404
  end

  test "unknown formats and bad pagination still 404" do
    get "/survivors", params: { page: 9999 }
    assert_response :not_found
    get "/episodes/no-such-episode"
    assert_response :not_found
  end

  test "a JSON request gets a small JSON 404, not an HTML page" do
    get "/no/such/page", headers: { "Accept" => "application/json" }
    assert_response :not_found
    assert_equal "application/json", response.media_type
    assert_equal 404, response.parsed_body["status"]
  end

  test "error pages are not counted as page views" do
    assert_difference("PageView.count", 1) { get "/", headers: BROWSER }          # control: normal pages are
    assert_no_difference("PageView.count") { get "/no/such/page", headers: BROWSER }
    assert_response :not_found
  end

  test "the error page itself works for a signed-in member" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    get "/no/such/page"
    assert_branded_404
  end

  test "a POST that fails with an error renders the error page without re-checking CSRF" do
    post "/no/such/page"
    assert_response :not_found
    assert_select "h1", text: /couldn.t find that page/i
  end

  test "an unhandled exception renders the branded 500 with the 500 status" do
    ShopCatalog.stub(:products, -> { raise "boom" }) do
      get "/shop"
    end
    assert_response :internal_server_error
    assert_select "h1", text: /went wrong on our end/i
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "if the full layout cannot render, a 500 degrades to the static page" do
    ErrorsController.send(:define_method, :forum_enabled?) { raise "database is down" }
    begin
      ShopCatalog.stub(:products, -> { raise "boom" }) do
        get "/shop"
      end
    ensure
      ErrorsController.send(:remove_method, :forum_enabled?)
    end
    assert_response :internal_server_error
    assert_equal Rails.public_path.join("500.html").read, response.body
    assert_no_match(/Primary/, response.body) # no site layout
  end

  test "422 and 400 render through the same controller with their own status" do
    { 422 => /change was rejected/i, 400 => /make sense/i, 406 => /show that page that way/i }.each do |code, heading|
      env = error_env("/#{code}")
      status, headers, body = ErrorsController.action(:show).call(env)
      assert_equal code, status
      html = body.each.to_a.join
      assert_match(heading, html)
      assert_match(/Primary/, html, "#{code} should render through the site layout, not the static page")
      assert_equal "noindex, nofollow", headers["X-Robots-Tag"]
    end
  end

  test "a 5xx other than 500 is treated as a server error page" do
    env = error_env("/503")
    status, _, body = ErrorsController.action(:show).call(env)
    assert_equal 503, status
    html = body.each.to_a.join
    assert_match(/went wrong on our end/i, html)
    assert_match(/Primary/, html)
  end

  test "an unexpected path is never trusted as a status" do
    env = error_env("/abc")
    status, = ErrorsController.action(:show).call(env)
    assert_equal 500, status
  end

  test "the static fallback pages carry the site name, lang, charset and noindex" do
    %w[400 404 422 500].each do |name|
      doc = Nokogiri::HTML(Rails.public_path.join("#{name}.html").read)
      assert_equal "en", doc.at_css("html")["lang"], name
      assert doc.at_css("meta[charset]"), name
      assert_match(/noindex/, doc.at_css("meta[name=robots]")["content"], name)
      assert_match(/Naked & Afraid Fan Wiki/, doc.at_css("title").text, name)
      assert doc.at_css("a[href='/']"), "#{name}: link home"
    end
  end
end
