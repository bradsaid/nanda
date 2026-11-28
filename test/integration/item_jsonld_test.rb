require "test_helper"
require "minitest/mock"

# Item pages: Product JSON-LD is only emitted with a real Offer; without a verified price the
# page is an ItemPage. Both branches are decided in JsonLdHelper#item_primary_jsonld.
class ItemJsonldTest < ActionDispatch::IntegrationTest
  PRICED = {
    "item" => "machete", "category" => "blade", "product" => "Test Machete", "brand" => "Acme",
    "match" => "confirmed", "price" => "24.99", "price_currency" => "usd",
    "buy" => [ { "url" => "https://www.amazon.com/dp/B000TEST" } ]
  }.freeze

  setup do
    series  = Series.create!(name: "Naked and Afraid")
    season  = Season.create!(series: series, number: 3, year: 2014)
    @episode = Episode.create!(season: season, number_in_season: 2, title: "Machete Tale", air_date: Date.new(2014, 1, 1), location: locations(:one), synopsis: "x")
    @survivor = Survivor.create!(full_name: "Ann Item")
    @appearance = Appearance.create!(episode: @episode, survivor: @survivor)
    @item = Item.create!(name: "Machete", item_type: "blade")
    AppearanceItem.create!(appearance: @appearance, item: @item, source: "brought")
  end

  def json_ld
    css_select('script[type="application/ld+json"]').flat_map { |n| parsed = JSON.parse(n.text); parsed.is_a?(Array) ? parsed : [ parsed ] }
  end

  def primary = json_ld.find { |s| %w[Product ItemPage].include?(s["@type"]) }

  def with_products(list)
    products = list.map { |h| h.with_indifferent_access.freeze }.freeze
    ShopCatalog.stub(:products, products) { yield }
  end

  test "with no verified price the page is an ItemPage, never a Product" do
    with_products([]) do
      get item_path(@item)
      assert_response :success
      assert_nil json_ld.find { |s| s["@type"] == "Product" }, "a Product without offers is invalid for rich results"
      page = primary
      assert_equal "ItemPage", page["@type"]
      assert_equal "machete", page["name"]
      assert_equal "Thing", page["about"]["@type"]
      assert_equal "machete", page["about"]["name"]
      assert_equal "blade", page["keywords"]
      assert_nil page["offers"]
      ep = page["about"]["subjectOf"].first
      assert_equal "TVEpisode", ep["@type"]
      assert_equal "Machete Tale", ep["name"]
      assert_equal 3, ep["seasonNumber"]
      assert json_ld.any? { |s| s["@type"] == "BreadcrumbList" }
    end
  end

  test "the shipped catalog has no prices, so no item page claims one" do
    assert ShopCatalog.products.none? { |p| p[:price].present? }, "if prices were added, review item_offer_jsonld"
    get item_path(@item)
    assert_equal "ItemPage", primary["@type"]
    assert_not_includes response.body, '"offers"'
  end

  test "with a price and currency in the catalog the page is a Product with that exact Offer" do
    with_products([ PRICED ]) do
      get item_path(@item)
      product = primary
      assert_equal "Product", product["@type"]
      assert_equal "machete", product["name"]
      assert_equal({ "@type" => "Offer", "price" => "24.99", "priceCurrency" => "USD",
                     "url" => "https://www.amazon.com/dp/B000TEST", "availability" => "https://schema.org/InStock" }, product["offers"])
      assert_equal %w[Given\ in\ episodes Brought\ in\ episodes Total\ appearances], product["additionalProperty"].map { |p| p["name"] }
    end
  end

  test "offer availability follows the catalog" do
    with_products([ PRICED.merge("availability" => "discontinued") ]) do
      get item_path(@item)
      assert_equal "https://schema.org/Discontinued", primary["offers"]["availability"]
    end
  end

  test "incomplete or malformed prices never produce an Offer" do
    [ PRICED.except("price"), PRICED.except("price_currency"), PRICED.merge("price" => "0"), PRICED.merge("price" => "free"),
      PRICED.merge("price" => "$24.99"), PRICED.merge("price_currency" => "dollars"), PRICED.except("buy"),
      PRICED.merge("item" => "other item") ].each do |bad|
      with_products([ bad ]) do
        get item_path(@item)
        assert_equal "ItemPage", primary["@type"], bad.inspect
      end
    end
  end
end
