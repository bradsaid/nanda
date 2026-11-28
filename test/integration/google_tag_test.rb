require "test_helper"

# The GA4 tag (G-8JGV4BSL96) must render as a well-formed, nonce'd gtag.js loader plus ONE
# nonce'd inline config, and nothing else on the page may load or configure GA4 a second time.
class GoogleTagTest < ActionDispatch::IntegrationTest
  GA_ID  = "G-8JGV4BSL96".freeze
  GTM_ID = "GTM-KG87PJGV".freeze

  def page(path = "/")
    get path
    assert_response :success
    Nokogiri::HTML(response.body)
  end

  def csp_script_nonce
    header = response.headers["Content-Security-Policy"].to_s
    directive = header.split(";").map(&:strip).find { |d| d.start_with?("script-src") }
    assert directive, "no script-src in CSP header: #{header}"
    directive[/'nonce-([^']+)'/, 1]
  end

  test "the gtag.js loader is exactly one well-formed async script carrying the nonce" do
    doc = page
    loaders = doc.css("script[src*='googletagmanager.com/gtag/js']")
    assert_equal 1, loaders.size
    loader = loaders.first
    assert_equal "https://www.googletagmanager.com/gtag/js?id=#{GA_ID}", loader["src"]
    assert loader.key?("async")
    assert loader["nonce"].present?
    assert_equal "", loader.text.strip, "the loader must have no inline body"
  end

  test "no malformed <script>async ...</script> tag is rendered" do
    page
    assert_no_match(/<script[^>]*>\s*async\b/i, response.body)
    assert_no_match(/<script[^>]*>[^<]*src=/i, response.body)
  end

  test "the inline gtag config appears once, with the nonce, and configures GA4 once" do
    doc = page
    inline = doc.css("script").select { |s| s.text.include?("gtag('config'") }
    assert_equal 1, inline.size
    assert inline.first["nonce"].present?
    assert_equal 1, response.body.scan("gtag('config', '#{GA_ID}')").size
    assert_equal 1, response.body.scan("gtag('js'").size
    assert_equal 1, response.body.scan("function gtag()").size
    assert_includes inline.first.text, "window.dataLayer = window.dataLayer || [];"
  end

  test "the script nonces match the CSP header's script-src nonce" do
    doc = page
    nonce = csp_script_nonce
    assert nonce.present?, "script-src must carry a nonce"
    loader = doc.at_css("script[src*='gtag/js']")
    inline = doc.css("script").find { |s| s.text.include?("gtag('config'") }
    assert_equal nonce, loader["nonce"]
    assert_equal nonce, inline["nonce"]
    assert_equal nonce, doc.at_css("script[type=importmap]")["nonce"]
  end

  test "the nonce changes between requests" do
    first = page.at_css("script[src*='gtag/js']")["nonce"]
    second = page.at_css("script[src*='gtag/js']")["nonce"]
    assert_not_equal first, second
  end

  test "CSP allows everything the GA4 snippet needs" do
    page
    csp = response.headers["Content-Security-Policy"].to_s
    directives = csp.split(";").map(&:strip).to_h { |d| d.split(" ", 2) }
    assert_includes directives["script-src"], "https://www.googletagmanager.com"
    %w[https://www.google-analytics.com https://region1.google-analytics.com
       https://analytics.google.com https://region1.analytics.google.com
       https://www.googletagmanager.com].each do |host|
      assert_includes directives["connect-src"], host
    end
    assert_includes directives["img-src"], "https://www.google-analytics.com"
    assert_includes directives["frame-src"], "https://www.googletagmanager.com"
  end

  # The container was emptied (its only tag duplicated the GA4 tag above), so the page no
  # longer loads it: no gtm.js bootstrap, no <noscript> iframe.
  test "the Google Tag Manager container is not loaded" do
    doc = page
    assert_empty doc.css("script[src*='/assets/gtag-']")
    assert_empty doc.css("iframe[src*='googletagmanager.com/ns.html']")
    assert_not_includes response.body, "gtm.js"
    assert_not_includes response.body, GTM_ID
    assert_not Rails.root.join("app/javascript/gtag.js").exist?
    js = Dir[Rails.root.join("app/javascript/**/*.js")].map { |f| File.read(f) }.join
    assert_not_includes js, GTM_ID
  end

  test "dead commented-out GTM/gtag blocks are gone from the layout" do
    layout = Rails.root.join("app/views/layouts/application.html.slim").read
    assert_no_match(%r{^\s*/javascript:}, layout)
    assert_no_match(/console\.log/, layout)
    assert_no_match(/gtm\.start/, layout)
  end

  test "no console.log/debug/info calls (live or commented out) in app/javascript" do
    offenders = Dir[Rails.root.join("app/javascript/**/*.js")].flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, i|
        "#{file.sub("#{Rails.root}/", '')}:#{i + 1}: #{line.strip}" if line.match?(/console\.(log|debug|info)\b/)
      end
    end
    assert_empty offenders, "remove console output from production JS:\n#{offenders.join("\n")}"
  end

  test "the GA4 tag is rendered on the home page and on a content page alike" do
    [ "/", "/survivors", "/episodes" ].each do |path|
      doc = page(path)
      assert_equal 1, doc.css("script[src*='gtag/js']").size, path
    end
  end
end
