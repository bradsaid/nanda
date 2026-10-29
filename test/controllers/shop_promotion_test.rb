require "test_helper"
require "minitest/mock"

# Where the Shop is promoted around the site: season, item-type, items-index and search,
# home, survivor, episode, podcasts, forum, and the gear guides.
class ShopPromotionTest < ActionDispatch::IntegrationTest
  PRODUCTS = [
    { item: "pot", category: "pot", product: "Named Pot", brand: "B", match: "confirmed", evidence_url: "https://e.com/n",
      survivors: ["Test Survivor A"], buy: [{ store: "amazon.com", url: "https://www.amazon.com/dp/B000000001" }] },
    { item: "pot", category: "pot", product: "Generic Pot", brand: "B", match: "similar", evidence_url: "https://e.com/g",
      buy: [{ store: "x.com", url: "https://x.com/g" }] },
    { item: "pot", category: "pot", product: "Third Pot", brand: "B", match: "similar", evidence_url: "https://e.com/t",
      buy: [{ store: "x.com", url: "https://x.com/t" }] },
    { item: "knife", category: "blade", product: "Plain Knife", brand: "B", match: "likely", evidence_url: "https://e.com/k",
      buy: [{ store: "x.com", url: "https://x.com/k" }] }
  ].map(&:with_indifferent_access).freeze

  setup do
    @pot   = Item.create!(name: "pot", item_type: "pot")
    @knife = Item.create!(name: "knife", item_type: "blade")
    AppearanceItem.create!(appearance: appearances(:one), item: @pot,   source: "brought")
    AppearanceItem.create!(appearance: appearances(:one), item: @knife, source: "given")
  end

  def with_products(&block) = ShopCatalog.stub(:products, PRODUCTS, &block)

  # --- 1. season pages ------------------------------------------------------

  test "a season page shows shop cards for the gear used that season" do
    with_products do
      get episodes_path(season_id: episodes(:one).season_id)
      assert_response :success
      assert_select ".shop-shelf h2", text: "Shop the Gear From This Season"
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot)
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@knife)
      assert_select ".shop-shelf .shop-disclosure", /Amazon Associate/
    end
  end

  # --- 2. item-type pages ---------------------------------------------------

  test "an item-type page shows shop cards for that type only" do
    with_products do
      get type_items_path("pot")
      assert_response :success
      assert_select ".shop-shelf h2", text: "Shop Pot Gear"
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot)
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@knife), 0
    end
  end

  # --- 3 & 7. items index and search ----------------------------------------

  test "the items index offers gear you can buy and badges items that have products" do
    with_products do
      get items_path
      assert_response :success
      assert_select ".shop-shelf h2", text: "Gear You Can Buy"
      assert_select "a.badge[href=?]", item_path(@pot, anchor: "item-shop"), text: "🛒 3"
      assert_select "a.badge[href=?]", item_path(@knife, anchor: "item-shop"), text: "🛒 1"
    end
  end

  test "searching items shows the matching items' products" do
    with_products do
      get items_path(q: "pot")
      assert_response :success
      assert_select ".shop-shelf h2", text: 'Shop "pot"'
      assert_select ".shop-shelf li.shop-product", text: /Named Pot/
      assert_select ".shop-shelf li.shop-product", text: /Plain Knife/, count: 0
    end
  end

  test "a search with no matching products shows no shelf" do
    with_products do
      get items_path(q: "zzzz")
      assert_response :success
      assert_select ".shop-shelf", 0
    end
  end

  # --- 4. home --------------------------------------------------------------

  test "the home page features gear from the latest episode" do
    episodes(:two).update_columns(air_date: Date.new(2020, 1, 1))
    episodes(:one).update_columns(air_date: Date.new(2021, 1, 1))   # latest: has the pot
    with_products do
      get root_path
      assert_response :success
      assert_select ".shop-shelf h2", text: "Gear From the Latest Episode"
      assert_select ".shop-shelf li.shop-product", text: /Named Pot/
      assert_select "a[href=?]", shop_path, text: /Browse the whole Shop/
    end
  end

  test "the home page features only confirmed products" do
    with_products do
      get root_path
      assert_select ".shop-shelf li.shop-product", 1                      # Named Pot only
      assert_no_match(/Generic Pot|Third Pot|Plain Knife/, response.body)  # similar / likely are left off
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@knife), 0
    end
  end

  test "the home page features only products that are on Amazon" do
    elsewhere = { item: "pot", category: "pot", product: "Confirmed Elsewhere Pot", brand: "B", match: "confirmed",
                  evidence_url: "https://e.com/ce", buy: [{ store: "x.com", url: "https://x.com/ce" }] }.with_indifferent_access
    ShopCatalog.stub(:products, PRODUCTS + [elsewhere]) do
      get root_path
      assert_select ".shop-shelf li.shop-product", 1
      assert_select ".shop-shelf li.shop-product", text: /Named Pot/
      assert_no_match(/Confirmed Elsewhere Pot/, response.body)
      assert_select ".shop-shelf a[href*='amazon.com']"
    end
    # Confirmed but not on Amazon: nothing to feature.
    ShopCatalog.stub(:products, [elsewhere]) do
      get root_path
      assert_select ".shop-shelf", 0
    end
  end

  test "the home page hides products that are out of stock or discontinued" do
    gone = ->(name, status) {
      { item: "pot", category: "pot", product: name, brand: "B", match: "confirmed", availability: status,
        evidence_url: "https://e.com/#{name.parameterize}",
        buy: [{ store: "amazon.com", url: "https://www.amazon.com/dp/B0#{name.length}" }] }.with_indifferent_access
    }
    products = PRODUCTS + [gone.("Sold Out Pot", "out_of_stock"), gone.("Retired Pot", "discontinued")]
    ShopCatalog.stub(:products, products) do
      get root_path
      assert_select ".shop-shelf li.shop-product", text: /Named Pot/
      assert_no_match(/Sold Out Pot|Retired Pot/, response.body)
    end
    # Only unavailable products: nothing to feature.
    ShopCatalog.stub(:products, [gone.("Sold Out Pot", "out_of_stock")]) do
      get root_path
      assert_select ".shop-shelf", 0
    end
  end

  test "elsewhere on the site an unavailable product still shows, with a badge" do
    sold_out = { item: "pot", category: "pot", product: "Sold Out Pot", brand: "B", match: "confirmed", availability: "out_of_stock",
                 evidence_url: "https://e.com/so", buy: [{ store: "amazon.com", url: "https://www.amazon.com/dp/B0SOLD" }] }.with_indifferent_access
    retired = sold_out.merge(product: "Retired Pot", availability: "discontinued", evidence_url: "https://e.com/rt")
    ShopCatalog.stub(:products, PRODUCTS + [sold_out, retired]) do
      get shop_path
      assert_select "li.shop-product", text: /Sold Out Pot/
      assert_select "li.shop-product .shop-availability", text: "Out of stock"
      assert_select "li.shop-product .shop-availability", text: "Discontinued"
      assert_select "li.shop-product", text: /Named Pot/
      assert_select "li.shop-product:has(.shop-availability)", 2
    end
  end

  test "available? and availability_label read the availability field" do
    assert ShopCatalog.available?({})
    assert ShopCatalog.available?({ availability: "" })
    assert_not ShopCatalog.available?({ availability: "out_of_stock" })
    assert_equal "Out of stock", ShopCatalog.availability_label({ availability: "out_of_stock" })
    assert_equal "Discontinued", ShopCatalog.availability_label({ availability: "discontinued" })
    assert_nil ShopCatalog.availability_label({})
  end

  test "the home page shows no shelf when nothing is confirmed" do
    ShopCatalog.stub(:products, PRODUCTS.reject { |p| p[:match] == "confirmed" }) do
      get root_path
      assert_response :success
      assert_select ".shop-shelf", 0
      assert_select "a", text: /Browse the whole Shop/, count: 0
    end
  end

  test "the home page falls back to the most-brought gear when the latest episode has none" do
    episodes(:one).update_columns(air_date: Date.new(2020, 1, 1))
    episodes(:two).update_columns(air_date: Date.new(2021, 1, 1))   # latest: no items at all
    appearances(:two).appearance_items.destroy_all
    with_products do
      get root_path
      assert_response :success
      assert_select ".shop-shelf h2", text: "Gear Survivors Bring Most"
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot)
    end
  end

  # --- 5. survivors ---------------------------------------------------------

  test "a survivor page links to its shop section" do
    with_products do
      get survivor_path(survivors(:one))
      assert_select "a.btn-warning[href=?]", "#survivor-shop", text: /Shop 1 product/
      assert_select "section#survivor-shop h2"
    end
  end

  test "the survivor directory marks survivors who have products" do
    with_products do
      get survivors_path
      assert_response :success
      assert_select "#survivors-results .badge", text: "🛒 1", count: 1
    end
  end

  # --- 6. episode jump link -------------------------------------------------

  test "an episode page has a jump link to its gear near the top" do
    with_products do
      get episode_path(episodes(:one))
      assert_select ".site-header a.btn-warning[href=?]", "#episode-shop", text: /product.* from this episode/
      assert_select "section#episode-shop h2"
    end
  end

  # --- 9. podcasts & books --------------------------------------------------

  test "the podcasts page links hosts and authors to their gear on the Shop page" do
    %w[Ky\ Furneaux MaLu\ Beyonce Jake\ Nodar Steven\ Kelly Cassie\ DePecol Stacey\ Osorio Tawny\ Lynn Jena\ Ocean
       Laura\ Zerra Shane\ Lewis Amber\ Shine Serena\ Shine Forrest\ Galante Quince\ Mountain Alison\ Teal].each { |n| Survivor.create!(full_name: n) }
    products = [
      { item: "knife", category: "blade", product: "Ky Knife", match: "confirmed", evidence_url: "https://e.com/ky",
        survivors: ["Ky Furneaux"], buy: [{ store: "x.com", url: "https://x.com/ky" }] }.with_indifferent_access
    ]
    ShopCatalog.stub(:products, products) do
      get podcasts_path
      assert_response :success
      links = css_select("a").select { |a| a["href"] == shop_path(q: "Ky Furneaux") }
      assert_operator links.size, :>=, 2   # the books header and the YouTube show card
      assert_match(/Gear used by Ky \(1\)/, links.first.text)
      assert_select "a[href*='q=Laura']", 0   # no products for her, no link
    end
  end

  test "the Shop search also finds products by the survivors they name" do
    with_products do
      get shop_path(q: "Test Survivor A")
      assert_select "li.shop-product", 1
      assert_select "li.shop-product", text: /Named Pot/
    end
  end

  # --- 8. forum -------------------------------------------------------------

  test "a forum thread shows shop cards for gear its posts mention" do
    ENV["FORUM_ENABLED"] = "true"
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Best cooking set?")
    topic.posts.create!(user: users(:one), body: "I always bring a pot, never a knife.")
    with_products do
      get forum_topic_path(topic)
      assert_response :success
      assert_select ".shop-shelf h2", text: "Gear Mentioned in This Thread"
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot)
    end
  ensure
    ENV["FORUM_ENABLED"] = nil
  end

  test "a forum thread that mentions no catalog gear has no shelf" do
    ENV["FORUM_ENABLED"] = "true"
    topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one), title: "Weather")
    topic.posts.create!(user: users(:one), body: "Nice day for a hike.")
    with_products do
      get forum_topic_path(topic)
      assert_response :success
      assert_select ".shop-shelf", 0
    end
  ensure
    ENV["FORUM_ENABLED"] = nil
  end

  test "mentioned_in matches whole words and plurals only, most-mentioned first" do
    with_products do
      assert_equal %w[pot knife], ShopCatalog.mentioned_in("pots, pot and a Pot. Also a knife")
      assert_equal [], ShopCatalog.mentioned_in("potato and knifeless")
      assert_equal [], ShopCatalog.mentioned_in("")
    end
  end

  # --- 10. gear guides ------------------------------------------------------

  test "the guides index lists a guide per gear category with enough products" do
    get shop_guides_path
    assert_response :success
    assert_select "h1", /Gear Guides/
    assert_select "a[href=?]", shop_guide_path("blade")
    assert_select ".shop-disclosure", /Amazon Associate/
    assert_select "a[href=?]", shop_guide_path("merch"), 0   # books and merch are not gear
  end

  test "a guide shows its category's products grouped by item, with sources and the disclosure" do
    get shop_guide_path("blade")
    assert_response :success
    assert_select "title", /Naked and Afraid/
    assert_select "h1", /Blades/
    assert_select "link[rel=canonical][href=?]", shop_guide_url("blade")
    assert_select "li.shop-product"
    assert_select ".shop-disclosure"
    assert_select "script[type='application/ld+json']", /ItemList/
    count = ShopCatalog.products.count { |p| p[:category] == "blade" }
    assert_select "li.shop-product", count
  end

  test "an unknown guide is a 404" do
    get shop_guide_path("nope")
    assert_response :not_found
  end

  test "the Shop page and item pages link to the guides" do
    get shop_path
    assert_select "a[href=?]", shop_guide_path("blade")

    knife = Item.create!(name: "machete")
    product = ShopCatalog.products.find { |p| p[:category] == "blade" }
    ShopCatalog.stub(:for_item, [product]) do
      get item_path(knife)
      assert_select "#item-shop a[href=?]", shop_guide_path("blade")
    end
  end

  test "guides are in the sitemap" do
    sitemap = File.read(Rails.root.join("config/sitemap.rb"))
    assert_match(/shop_guides_path/, sitemap)
    assert_match(/shop_guide_path/, sitemap)
  end
end
