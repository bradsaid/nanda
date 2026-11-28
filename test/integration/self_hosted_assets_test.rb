require "test_helper"

# Bootstrap CSS and the Montserrat fonts are served from this origin through Propshaft
# (digested, cacheable), not from cdn.jsdelivr.net / fonts.googleapis.com / fonts.gstatic.com.
class SelfHostedAssetsTest < ActionDispatch::IntegrationTest
  def page(path = "/")
    get path
    assert_response :success
    Nokogiri::HTML(response.body)
  end

  test "Bootstrap CSS is a digested same-origin stylesheet, linked before application.css" do
    doc = page
    sheets = doc.css("head link[rel=stylesheet]").map { |l| l["href"] }
    bootstrap = sheets.index { |h| h =~ %r{\A/assets/vendor/bootstrap\.min-[0-9a-f]+\.css\z} }
    app       = sheets.index { |h| h =~ %r{\A/assets/application-[0-9a-f]+\.css\z} }
    assert bootstrap, "expected a self-hosted bootstrap stylesheet, got #{sheets.inspect}"
    assert app
    assert_operator bootstrap, :<, app
    assert_equal 1, sheets.count { |h| h.include?("bootstrap") }
  end

  test "Bootstrap is not loaded from jsdelivr" do
    page
    assert_no_match(%r{cdn\.jsdelivr\.net/npm/bootstrap}, response.body)
  end

  test "bootstrap and application stylesheets are preloaded" do
    doc = page
    preloads = doc.css("head link[rel=preload][as=style]").map { |l| l["href"] }
    assert preloads.any? { |h| h.include?("/assets/vendor/bootstrap.min-") }
    assert preloads.any? { |h| h.include?("/assets/application-") }
  end

  test "the vendored file is Bootstrap 5.3.3 and application.css does not @import it again" do
    css = Rails.root.join("app/assets/stylesheets/vendor/bootstrap.min.css").read
    assert_match(/Bootstrap\s+v5\.3\.3/, css)
    app = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_no_match(/^\s*@import\s/, app)
  end

  test "the Bootstrap stylesheet URL resolves and serves CSS" do
    href = page.at_css("head link[rel=stylesheet][href*='bootstrap']")["href"]
    get href
    assert_response :success
    assert_match(%r{text/css}, response.media_type.to_s + "/css")
    assert_includes response.body, "Bootstrap"
  end
end
