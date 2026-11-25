require "test_helper"
require "rack/mock"

# Production forces HTTPS via ActionDispatch::SSL. That middleware is not in the
# test stack (config.force_ssl is only set in production.rb), so this covers it
# two ways:
#
#   1. The production config file still enables force_ssl and does NOT enable
#      assume_ssl. assume_ssl rewrites every request to X-Forwarded-Proto: https
#      before ActionDispatch::SSL sees it, so the redirect never fires. That was
#      the bug: http://www.nakedandafraidfan.com/ answered 200 over plain HTTP.
#   2. ActionDispatch::SSL, built with the same default options production uses,
#      behaves as expected behind a proxy that sets X-Forwarded-Proto (Heroku).
class ForceSslTest < ActiveSupport::TestCase
  PRODUCTION_RB = Rails.root.join("config/environments/production.rb").read

  def active_config_lines
    PRODUCTION_RB.lines.reject { |l| l.strip.start_with?("#") }.join
  end

  test "production enables force_ssl" do
    assert_match(/^\s*config\.force_ssl\s*=\s*true\b/, active_config_lines)
  end

  test "production does not assume SSL (that would disable the redirect)" do
    assert_no_match(/assume_ssl/, active_config_lines)
  end

  test "production does not exclude paths from the https redirect" do
    assert_no_match(/ssl_options/, active_config_lines)
  end

  # --- behaviour of ActionDispatch::SSL with production's (default) options ---

  def ssl_app
    inner = ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "ok" ] ] }
    ActionDispatch::SSL.new(inner)
  end

  def call(path, method: "GET", proto: "http", host: "www.nakedandafraidfan.com", query: nil)
    env = Rack::MockRequest.env_for("http://#{host}#{path}#{query ? "?#{query}" : ""}", method: method)
    env["HTTP_X_FORWARDED_PROTO"] = proto
    ssl_app.call(env)
  end

  test "http GET is 301-redirected to https with the same host, path and query" do
    status, headers, _ = call("/survivors", query: "q=bear&page=2")
    assert_equal 301, status
    assert_equal "https://www.nakedandafraidfan.com/survivors?q=bear&page=2", headers["location"]
  end

  test "http HEAD is 301-redirected too" do
    status, headers, _ = call("/episodes", method: "HEAD")
    assert_equal 301, status
    assert_equal "https://www.nakedandafraidfan.com/episodes", headers["location"]
  end

  test "http POST (e.g. /page_view_ping) is redirected with 307 so the method is preserved" do
    status, headers, _ = call("/page_view_ping", method: "POST")
    assert_equal 307, status
    assert_equal "https://www.nakedandafraidfan.com/page_view_ping", headers["location"]
  end

  test "the herokuapp.com host redirects to https on the same host" do
    status, headers, _ = call("/", host: "nanda.herokuapp.com")
    assert_equal 301, status
    assert_equal "https://nanda.herokuapp.com/", headers["location"]
  end

  test "https requests pass through and carry HSTS" do
    status, headers, body = call("/survivors", proto: "https")
    assert_equal 200, status
    assert_equal [ "ok" ], body.to_a
    assert_match(/max-age=\d+/, headers["strict-transport-security"])
  end
end
