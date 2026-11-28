require "test_helper"
require "rack/mock"

# The GoDaddy forward only handled "https://nakedandafraidfan.com/", so every deep link on the bare
# domain 404'd. Once the apex points at Heroku, Middleware::CanonicalHostRedirect 301s it to www.
#
# Two layers are covered:
#   * the real (test) application stack, through integration requests with host! / https!(false);
#   * the production stack order (CanonicalHostRedirect -> ActionDispatch::SSL -> TrailingSlashRedirect
#     -> app) rebuilt by hand, because ActionDispatch::SSL is only installed when force_ssl is on.
class CanonicalHostRedirectTest < ActionDispatch::IntegrationTest
  WWW = "https://www.nakedandafraidfan.com".freeze

  # --- the real application stack -------------------------------------------------------

  test "the middleware is the first thing in the application stack" do
    names = Rails.application.middleware.map(&:inspect)
    assert_equal "Middleware::CanonicalHostRedirect", names.first
    assert_operator names.index("Middleware::CanonicalHostRedirect"), :<, names.index("Middleware::TrailingSlashRedirect")
  end

  test "an https deep link on the bare domain 301s to the same path on www" do
    host! "nakedandafraidfan.com"
    get "/about"
    assert_response :moved_permanently
    assert_equal "#{WWW}/about", response.headers["Location"]
  end

  test "path and query string are kept" do
    host! "nakedandafraidfan.com"
    get "/episodes/by_country/Peru?sort=name&q=a%20b&page=2"
    assert_response :moved_permanently
    assert_equal "#{WWW}/episodes/by_country/Peru?sort=name&q=a%20b&page=2", response.headers["Location"]
  end

  test "an http request on the bare domain goes to https www in a single hop" do
    host! "nakedandafraidfan.com"
    https!(false)
    get "/survivors?page=3"
    assert_response :moved_permanently
    assert_equal "#{WWW}/survivors?page=3", response.headers["Location"]
  end

  test "the bare-domain root goes to the www root" do
    host! "nakedandafraidfan.com"
    get "/"
    assert_response :moved_permanently
    assert_equal "#{WWW}/", response.headers["Location"]
  end

  test "a trailing slash is dropped in the same redirect" do
    host! "nakedandafraidfan.com"
    get "/forum/guidelines/?x=1"
    assert_response :moved_permanently
    assert_equal "#{WWW}/forum/guidelines?x=1", response.headers["Location"]
  end

  test "HEAD is a 301 and POST is a 308 so the method survives" do
    host! "nakedandafraidfan.com"
    head "/about"
    assert_response :moved_permanently
    post "/contact", params: { name: "x" }
    assert_response 308
    assert_equal "#{WWW}/contact", response.headers["Location"]
  end

  test "the www host is not redirected and serves pages" do
    host! "www.nakedandafraidfan.com"
    get "/about"
    assert_response :success
  end

  test "the www host with a trailing slash still gets only the trailing-slash redirect" do
    host! "www.nakedandafraidfan.com"
    get "/about/"
    assert_response :moved_permanently
    assert_equal "/about", response.headers["Location"]
  end

  test "herokuapp, localhost and the default test host are never redirected" do
    [ "nanda.herokuapp.com", "localhost", "127.0.0.1", "www.example.com", "example.com" ].each do |host|
      host! host
      get "/about"
      assert_response :success, host
    end
  end

  test "look-alike hosts are not redirected" do
    [ "evilnakedandafraidfan.com", "nakedandafraidfan.com.evil.example", "sub.nakedandafraidfan.com" ].each do |host|
      host! host
      get "/about"
      assert_not_equal 301, response.status, host
    end
  end

  # --- the middleware class on its own --------------------------------------------------

  def middleware
    @middleware ||= Middleware::CanonicalHostRedirect.new(->(_env) { [ 200, { "content-type" => "text/plain" }, [ "app" ] ] })
  end

  def env_for(path = "/", host: "nakedandafraidfan.com", method: "GET", query: nil, scheme: "https")
    env = Rack::MockRequest.env_for("#{scheme}://#{host}#{path}#{"?#{query}" if query}", method: method)
    env["HTTP_HOST"] = host
    env
  end

  test "host matching ignores case, a port and a trailing dot" do
    [ "NakedAndAfraidFan.com", "nakedandafraidfan.com:80", "nakedandafraidfan.com:443", "nakedandafraidfan.com." ].each do |host|
      status, headers, = middleware.call(env_for("/about", host: host))
      assert_equal 301, status, host
      assert_equal "#{WWW}/about", headers["location"], host
    end
  end

  test "requests with no usable host pass through" do
    env = env_for("/about")
    env.delete("HTTP_HOST")
    env["SERVER_NAME"] = ""
    assert_equal 200, middleware.call(env).first
    env["SERVER_NAME"] = "www.nakedandafraidfan.com"
    assert_equal 200, middleware.call(env).first
  end

  test "a health-check style request to any non-apex host passes through" do
    %w[nanda.herokuapp.com localhost 10.0.0.12 www.nakedandafraidfan.com].each do |host|
      assert_equal 200, middleware.call(env_for("/up", host: host, scheme: "http")).first, host
    end
  end

  test "control characters, spaces and raw bytes in the path or query are escaped, never injected into headers" do
    env = env_for("/a")
    env["PATH_INFO"] = "/a b\r\nSet-Cookie: x=1/\xFF".b
    env["QUERY_STRING"] = "q=\xC3\xA9&r=\n".b
    status, headers, = middleware.call(env)
    assert_equal 301, status
    location = headers["location"]
    assert_equal "#{WWW}/a%20b%0D%0ASet-Cookie:%20x=1/%FF", location.split("?").first
    assert_equal "q=%C3%A9&r=%0A", location.split("?").last
    assert_no_match(/[\r\n]/, location)
    assert location.ascii_only?
  end

  test "an invalid-UTF-8 path labelled as UTF-8 does not raise" do
    env = env_for("/a")
    env["PATH_INFO"] = "/ab\xFF/".dup.force_encoding("UTF-8")
    status, headers, = middleware.call(env)
    assert_equal 301, status
    assert_equal "#{WWW}/ab%FF", headers["location"]
  end

  test "a path that starts with extra slashes stays on the canonical host" do
    status, headers, = middleware.call(env_for("//evil.example.com/"))
    assert_equal 301, status
    assert headers["location"].start_with?("#{WWW}/"), headers["location"]
  end

  test "admin, assets and active storage paths keep their trailing slash on the bare domain" do
    status, headers, = middleware.call(env_for("/admin/"))
    assert_equal 301, status
    assert_equal "#{WWW}/admin/", headers["location"]
  end

  # --- production stack order -----------------------------------------------------------

  def production_stack(inner = ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "app" ] ] })
    Rack::Builder.app do
      use Middleware::CanonicalHostRedirect
      use ActionDispatch::SSL
      use Middleware::TrailingSlashRedirect
      run inner
    end
  end

  def prod_call(url, proto: "http", method: "GET", host: nil)
    env = Rack::MockRequest.env_for(url, method: method)
    env["HTTP_HOST"] = host if host
    env["HTTP_X_FORWARDED_PROTO"] = proto
    production_stack.call(env)
  end

  # Follow redirects through the hand-built stack, counting hops.
  def hops(url, proto: "http")
    chain = []
    loop do
      uri = URI(url)
      status, headers, = prod_call(url, proto: uri.scheme == "https" ? "https" : proto)
      return [ status, chain, url ] unless [ 301, 308 ].include?(status)
      chain << headers["location"]
      url = URI.join(url, headers["location"]).to_s # TrailingSlashRedirect answers with a relative path
      raise "redirect loop: #{chain.inspect}" if chain.size > 5
    end
  end

  test "http://nakedandafraidfan.com/x is a single hop to https://www" do
    status, chain, final = hops("http://nakedandafraidfan.com/about?x=1")
    assert_equal 200, status
    assert_equal [ "#{WWW}/about?x=1" ], chain
    assert_equal "#{WWW}/about?x=1", final
  end

  test "http://nakedandafraidfan.com/x/ (trailing slash) is still a single hop" do
    status, chain, = hops("http://nakedandafraidfan.com/about/?x=1")
    assert_equal 200, status
    assert_equal [ "#{WWW}/about?x=1" ], chain
  end

  test "https://nakedandafraidfan.com/x is a single hop" do
    status, chain, = hops("https://nakedandafraidfan.com/about")
    assert_equal 200, status
    assert_equal 1, chain.size
  end

  test "http://www.nakedandafraidfan.com/path 301s to https www without erroring" do
    status, headers, = prod_call("http://www.nakedandafraidfan.com/about")
    assert_equal 301, status
    assert_equal "#{WWW}/about", headers["location"]
  end

  test "http www with a trailing slash takes two hops at most" do
    status, chain, = hops("http://www.nakedandafraidfan.com/about/")
    assert_equal 200, status
    assert_operator chain.size, :<=, 2
  end

  test "http www with a weird path and query redirects cleanly" do
    [
      "/a%20b/c?x=%E0%A4%A&y[]=1&z=%",
      "/%C3%A9?q=caf%C3%A9&utm_source=a%2Fb",
      "/search?q=" + "x" * 2000,
      "//double//slash?x"
    ].each do |path_and_query|
      status, headers, = prod_call("http://www.nakedandafraidfan.com#{path_and_query}")
      assert_equal 301, status, path_and_query
      assert_match(%r{\Ahttps://www\.nakedandafraidfan\.com/}, headers["location"], path_and_query)
    end
  end

  test "http www with raw invalid bytes in the path still redirects instead of raising" do
    env = Rack::MockRequest.env_for("http://www.nakedandafraidfan.com/a")
    env["HTTP_X_FORWARDED_PROTO"] = "http"
    env["PATH_INFO"] = "/ab\xFF/".dup.force_encoding("UTF-8")
    status, headers, = production_stack.call(env)
    assert_equal 301, status
    assert headers["location"].start_with?("https://www.nakedandafraidfan.com/")
  end

  test "https www with raw invalid bytes and a trailing slash does not raise in the slash middleware" do
    env = Rack::MockRequest.env_for("https://www.nakedandafraidfan.com/a")
    env["HTTP_X_FORWARDED_PROTO"] = "https"
    env["PATH_INFO"] = "/ab\xFF/".dup.force_encoding("UTF-8")
    status, headers, = production_stack.call(env)
    assert_equal 301, status
    assert_equal "/ab\xFF".b, headers["location"].b
  end

  test "http POST to www is redirected with 307 so the method survives" do
    status, headers, = prod_call("http://www.nakedandafraidfan.com/page_view_ping", method: "POST")
    assert_equal 307, status
    assert_equal "#{WWW}/page_view_ping", headers["location"]
  end

  test "https www passes through with HSTS" do
    status, headers, = prod_call("https://www.nakedandafraidfan.com/about", proto: "https")
    assert_equal 200, status
    assert_match(/max-age=\d+/, headers["strict-transport-security"])
  end

  test "herokuapp.com http is redirected to https on the same host, not to www" do
    status, headers, = prod_call("http://nanda.herokuapp.com/about")
    assert_equal 301, status
    assert_equal "https://nanda.herokuapp.com/about", headers["location"]
  end
end
