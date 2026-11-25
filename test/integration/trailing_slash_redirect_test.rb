require "test_helper"
require "rack/mock"

# "/forum/" and "/survivors/" used to answer 200 as a second URL for the same page.
class TrailingSlashRedirectTest < ActionDispatch::IntegrationTest
  test "the middleware is installed ahead of static files and the router" do
    names = Rails.application.middleware.map(&:inspect)
    mine  = names.index("Middleware::TrailingSlashRedirect")
    assert mine, "middleware missing from the stack"
    assert_operator mine, :<, names.index("Rack::Sendfile")
    assert_operator mine, :<, names.index("ActionDispatch::Static") if names.include?("ActionDispatch::Static")
  end

  test "a trailing-slash page URL 301s to the clean path" do
    %w[/survivors/ /episodes/ /forum/ /items/ /locations/ /about/ /shop/ /forum/guidelines/ /episodes/by_country/Peru/].each do |path|
      get path
      assert_response :moved_permanently, path
      assert_equal path.chomp("/"), response.headers["Location"], path
    end
  end

  test "the query string is preserved" do
    get "/survivors/?sort=name&q=a%20b"
    assert_response :moved_permanently
    assert_equal "/survivors?sort=name&q=a%20b", response.headers["Location"]
  end

  test "HEAD requests are redirected too" do
    head "/survivors/"
    assert_response :moved_permanently
    assert_equal "/survivors", response.headers["Location"]
  end

  test "the redirect target then serves the page" do
    get "/survivors/"
    follow_redirect!
    assert_response :success
  end

  test "the root and unslashed paths are untouched" do
    get "/"
    assert_response :success
    get "/survivors"
    assert_response :success
  end

  test "POST requests are not redirected" do
    post "/contact/", params: { name: "x" }
    assert_not_equal 301, response.status
  end

  test "assets, active storage and admin paths are skipped" do
    %w[/assets/ /assets/application.css/ /rails/active_storage/blobs/x/ /admin/ /admin/survivors/].each do |path|
      get path
      assert_not_equal 301, response.status, "#{path} must not be slash-redirected"
    end
  end

  test "repeated and leading slashes cannot produce a redirect to another host" do
    app = Middleware::TrailingSlashRedirect.new(->(_env) { [200, {}, ["ok"]] })
    ["//evil.example.com/", "///evil.example.com//", "//"].each do |path|
      status, headers, = app.call(Rack::MockRequest.env_for("/").merge("PATH_INFO" => path))
      assert_equal 301, status, path
      location = headers["location"]
      assert location.start_with?("/") && !location.start_with?("//"), "#{path} -> #{location.inspect} must stay on this host"
    end
  end

  test "non-slash and root requests pass straight through the middleware" do
    app = Middleware::TrailingSlashRedirect.new(->(_env) { [200, {}, ["ok"]] })
    assert_equal 200, app.call(Rack::MockRequest.env_for("/")).first
    assert_equal 200, app.call(Rack::MockRequest.env_for("/forum")).first
    assert_equal 200, app.call(Rack::MockRequest.env_for("/forum/", method: "POST")).first
  end
end
