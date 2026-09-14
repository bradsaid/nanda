require "test_helper"

# ApplicationController sets `allow_browser versions: :modern unless
# Rails.env.test?`, so the 406 itself can't be exercised here. What can be
# guarded is the file Rails renders for it and the constraint that makes it
# useful: it is shown only to browsers too old for the app, so it must not
# depend on the CSS features those browsers lack.
class UnsupportedBrowserPageTest < ActiveSupport::TestCase
  PAGE = Rails.root.join("public/406-unsupported-browser.html")

  setup { @html = PAGE.read }

  test "exists at the path Rails renders for a blocked browser" do
    assert PAGE.exist?, "allow_browser renders this exact path"
  end

  test "is branded as the site rather than the stock Rails page" do
    assert_match "Naked &amp; Afraid Fan Wiki", @html
    assert_no_match(/viewBox="0 0 480 172"/, @html, "stock Rails logo should be gone")
  end

  test "tells the visitor what to actually do" do
    assert_match "google.com/chrome",      @html
    assert_match "mozilla.org/firefox",    @html
    assert_match "microsoft.com/edge",     @html
  end

  test "stays indexable-safe" do
    assert_match(/<meta name="robots" content="noindex, nofollow">/, @html)
  end

  # The page the stock Rails file shipped used grid, clamp() and CSS nesting —
  # none of which the browsers it targets can parse.
  test "avoids CSS the target browsers cannot parse" do
    css = @html[/<style>(.+?)<\/style>/m, 1].to_s
    assert css.present?, "expected inline CSS"
    assert_no_match(/display:\s*grid/,  css, "grid is unsupported on old browsers")
    assert_no_match(/display:\s*flex/,  css, "flexbox is unreliable on old browsers")
    assert_no_match(/clamp\(/,          css, "clamp() is unsupported on old browsers")
    assert_no_match(/var\(--/,          css, "custom properties are unsupported on old browsers")
    assert_no_match(/@media[^{]*\{[^}]*\{/m, css, "nested CSS is unsupported on old browsers")
  end
end
