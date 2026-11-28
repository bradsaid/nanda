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

  test "no googleapis/gstatic stylesheet, preconnect or font URL anywhere in the page" do
    page
    assert_no_match(%r{fonts\.googleapis\.com|fonts\.gstatic\.com}, response.body)
  end

  test "Montserrat is preloaded as a same-origin woff2 with crossorigin" do
    doc = page
    preloads = doc.css("head link[rel=preload][as=font]")
    assert_equal 1, preloads.size
    link = preloads.first
    assert_equal "font/woff2", link["type"]
    assert link.key?("crossorigin")
    assert_match(%r{\A/assets/montserrat-latin-wght-[0-9a-f]+\.woff2\z}, link["href"])
  end

  test "inline @font-face rules use font-display swap and digested same-origin files" do
    doc = page
    css = doc.css("head style").map(&:text).join
    faces = css.scan(/@font-face\{[^}]*\}/)
    assert_equal 2, faces.size
    faces.each do |face|
      assert_includes face, 'font-family:"Montserrat"'
      assert_includes face, "font-display:swap"
      assert_match(%r{src:url\(/assets/montserrat-[a-z-]*latin-wght-[0-9a-f]+\.woff2\) format\("woff2"\)}, face)
      assert_includes face, "unicode-range:U+0000-00FF"
    end
    assert_includes faces.first, "font-weight:400 900"
  end

  test "the font files exist and the digested URLs are served as font/woff2" do
    doc = page
    hrefs = [ doc.at_css("link[rel=preload][as=font]")["href"],
              doc.at_css("head style").text[%r{url\((/assets/montserrat-italic-latin-wght-[0-9a-f]+\.woff2)\)}, 1] ]
    hrefs.each do |href|
      assert href, "font URL missing"
      get href
      assert_response :success
      assert_equal "font/woff2", response.media_type
      assert_operator response.body.bytesize, :>, 10_000
    end
  end

  test "CSP font-src permits same-origin fonts" do
    page
    font_src = response.headers["Content-Security-Policy"].split(";").map(&:strip).find { |d| d.start_with?("font-src") }
    assert_includes font_src, "'self'"
  end
end
