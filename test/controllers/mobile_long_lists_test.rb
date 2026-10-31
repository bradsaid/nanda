require "test_helper"
require "minitest/mock"

# /survivors, /shop and /items are very long on a phone. The mobile pass makes them denser with
# CSS plus closed <details>, and adds jump links and a back-to-top link. None of it may remove
# content from the server-rendered HTML, and #anchors must keep resolving.
class MobileLongListsTest < ActionDispatch::IntegrationTest
  PRODUCTS = [
    { item: "pot", category: "pot", product: "CanCooker Jr.", brand: "CanCooker", match: "likely",
      survivors: ["Test Survivor A"], used_by: "Season 8", evidence_url: "https://example.com/e",
      evidence: "Fans say so", more_sources: ["https://example.com/e2"],
      buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B0B74MT6VM", asin: "B0B74MT6VM" }] },
    { item: "", category: "blade", product: "Gator Machete", brand: "Gerber", match: "confirmed",
      buy: [{ store: "rei.com", url: "https://www.rei.com/x" }] },
    { item: "", category: "media", product: "Season 19", brand: "Discovery", match: "confirmed",
      used_by: "Everyone", buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B0GLV8K4K3", asin: "B0GLV8K4K3" }] }
  ].map(&:with_indifferent_access).freeze

  def with_products(&block) = ShopCatalog.stub(:products, PRODUCTS, &block)

  # --- survivors ----------------------------------------------------------

  test "survivors sorted A-Z get a letter nav whose anchors exist, and everyone stays in the HTML" do
    %w[Aaron\ Alpha Bea\ Beta Zed\ Zulu].each { |n| Survivor.create!(full_name: n) }

    get survivors_path(sort: "name")
    assert_response :success

    letters = css_select("nav.survivor-az a").map { |a| [a.text.strip, a["href"]] }
    assert_includes letters.map(&:first), "A"
    assert_includes letters.map(&:first), "Z"
    letters.each do |_, href|
      assert_equal 1, css_select(href).size, "#{href} should resolve to exactly one element"
    end

    names = css_select("#survivors-results .survivor-name-stack").map { |n| [n.at_css(".first-name").text, n.at_css(".last-name").text].join(" ") }
    assert_equal Survivor.count, names.size
    assert_includes names, "Zed Zulu"
    assert_select "a.back-to-top[href=?]", "#top"
  end

  test "other survivor sorts have no letter nav but still link back to top" do
    get survivors_path(sort: "episodes")
    assert_response :success
    assert_select "nav.survivor-az", 0
    assert_select "#survivors-results [id^=az-]", 0
    assert_select "a.back-to-top"
  end

  # --- shop ---------------------------------------------------------------

  test "shop cards keep all details in the HTML inside a closed details element" do
    with_products do
      get shop_path
      assert_response :success
      assert_select "li.shop-product", 3

      first = css_select("li.shop-product").find { |li| li.text.include?("CanCooker") }
      details = first.css("details.shop-more")
      assert_equal 1, details.size
      assert_nil details.first["open"], "details start closed (the CSS opens them on desktop and for #anchors)"
      body = details.first.text
      assert_includes body, "Season 8"
      assert_includes body, "Fans say so"
      assert_includes body, "Source 2"
      assert_equal "Details & sources", details.first.at_css("summary").text.strip

      # The name, badge and buy button stay outside the collapsed part.
      assert_nil details.first.at_css(".shop-buy")
      assert first.at_css(".shop-product-actions .shop-buy")

      # A product with nothing secondary has no empty toggle.
      machete = css_select("li.shop-product").find { |li| li.text.include?("Gator Machete") }
      assert_empty machete.css("details")
    end
  end

  test "shop anchors still resolve and the category jump links point at real cards" do
    with_products do
      get shop_path
      ids = css_select("li.shop-product").map { |li| li["id"] }
      assert_equal ids.uniq, ids
      assert ids.all? { |i| i.start_with?("p-") }

      jump = css_select("nav.shop-jump a")
      assert_equal 3, jump.size
      jump.each { |a| assert_equal 1, css_select(a["href"]).size, "#{a['href']} should exist" }
      assert_select "a.back-to-top"
    end
  end

  test "a filtered shop with one category skips the jump nav" do
    with_products do
      get shop_path, params: { category: "blade" }
      assert_select "nav.shop-jump", 0
    end
  end

  test "guide pages use the same compact cards and have a back-to-top link" do
    guide = ShopCatalog.guides.first
    skip "no guides in the catalog" unless guide
    get shop_guide_path(guide.slug)
    assert_response :success
    assert_select "a.back-to-top"
  end

  # --- items --------------------------------------------------------------

  test "items per country are closed details on first load with every row still in the HTML" do
    item = Item.create!(name: "zzmobileitem")
    AppearanceItem.create!(appearance: appearances(:one), item: item, source: "brought", quantity: 1)

    get items_path
    assert_response :success

    cards = css_select("details.m-collapse-card")
    assert_operator cards.size, :>=, 1
    assert cards.none? { |c| c["open"] }, "unfiltered cards start closed"
    assert_includes cards.map(&:text).join, "zzmobileitem"
    assert css_select("nav.items-jump a").all? { |a| css_select(a["href"]).size == 1 }
    assert_select "a.back-to-top"
  end

  test "filtering items by country renders that country's card open" do
    item = Item.create!(name: "zzmobileitem2")
    AppearanceItem.create!(appearance: appearances(:one), item: item, source: "brought", quantity: 1)
    country = appearances(:one).episode.location.country

    get items_path(country: country)
    assert_response :success
    cards = css_select("details.m-collapse-card")
    assert_operator cards.size, :>=, 1
    assert cards.all? { |c| c["open"] }, "filtered view shows the card open"
  end
end
