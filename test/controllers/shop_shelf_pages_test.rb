require "test_helper"
require "minitest/mock"

# Shop cards on episode pages (gear brought or given there) and survivor pages (gear
# the survivor brought), public, with the affiliate disclosure.
class ShopShelfPagesTest < ActionDispatch::IntegrationTest
  def product(name, item:, match: "similar", **extra)
    { item: item, category: "pot", product: name, brand: "B", match: match, evidence_url: "https://e.com/#{name.parameterize}",
      buy: [{ store: "x.com", url: "https://x.com/#{name.parameterize}" }] }.merge(extra).with_indifferent_access
  end

  PRODUCTS = [
    { item: "pot", category: "pot", product: "Named Pot", match: "similar", evidence_url: "https://e.com/n",
      survivors: ["Test Survivor A"], buy: [{ store: "x.com", url: "https://x.com/n" }] },
    { item: "pot", category: "pot", product: "Episode Pot", match: "similar", evidence_url: "https://e.com/e",
      episodes: [{ series: "TestSeriesA", season: 1, title: "Test Episode A" }], buy: [{ store: "x.com", url: "https://x.com/e" }] },
    *(1..4).map { |i| { item: "pot", category: "pot", product: "Generic Pot #{i}", match: "likely", evidence_url: "https://e.com/g#{i}",
                        buy: [{ store: "x.com", url: "https://x.com/g#{i}" }] } },
    { item: "knife", category: "blade", product: "Given Knife", match: "likely", evidence_url: "https://e.com/k",
      buy: [{ store: "x.com", url: "https://x.com/k" }] },
    { item: "salt", category: "other", product: "Found Salt", match: "likely", evidence_url: "https://e.com/s",
      buy: [{ store: "x.com", url: "https://x.com/s" }] }
  ].map(&:with_indifferent_access).freeze

  setup do
    @pot   = Item.create!(name: "pot")
    @knife = Item.create!(name: "knife")
    @salt  = Item.create!(name: "salt")
    a1 = appearances(:one)
    a2 = appearances(:two)
    AppearanceItem.create!(appearance: a1, item: @pot,   source: "brought")
    AppearanceItem.create!(appearance: a1, item: @knife, source: "given")
    AppearanceItem.create!(appearance: a1, item: @salt,  source: "found")
    AppearanceItem.create!(appearance: a2, item: @pot,   source: "given")
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def with_products(&block) = ShopCatalog.stub(:products, PRODUCTS, &block)

  # --- episode page ---------------------------------------------------------

  test "visitors see shop cards for the items brought or given in the episode" do
    with_products do
      get episode_path(episodes(:one))
      assert_response :success
      assert_select ".shop-shelf h2", text: "Shop the Gear From This Episode"
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot)
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@knife)
      assert_select ".shop-shelf li.shop-product", text: /Given Knife/
    end
  end

  test "found items are not shopped, and neither are items from other episodes" do
    with_products do
      get episode_path(episodes(:one))
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@salt), 0
      assert_no_match(/Found Salt/, response.body)
    end
    with_products do
      get episode_path(episodes(:two))
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@knife), 0
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot)   # given there
    end
  end

  test "products that name this episode or a survivor with the item come first, labelled" do
    with_products do
      get episode_path(episodes(:one))
      names = css_select(".shop-shelf li.shop-product .fw-semibold").map { |n| n.text.strip }.select { |n| n.include?("Pot") }
      assert_match(/Episode Pot/, names[0])
      assert_match(/Named Pot/, names[1])
      assert_select ".shop-specific", text: "Seen in this episode"
      assert_select ".shop-specific", text: "Used by Test Survivor A"
    end
  end

  test "each item is capped, with a link to see them all" do
    with_products do
      get episode_path(episodes(:one))
      pots = css_select(".shop-shelf li.shop-product").select { |li| li.text.include?("Pot") }
      assert_equal 4, pots.size
      assert_match(/Showing 4 of 6/, response.body)
      assert_select ".shop-shelf a[href=?]", item_path(@pot), text: "see all"
    end
  end

  test "the episode shelf carries the affiliate disclosure" do
    with_products do
      get episode_path(episodes(:one))
      assert_select ".shop-shelf .shop-disclosure", /Amazon Associate/
      assert_select ".shop-shelf", text: /Admin preview/, count: 0
    end
  end

  test "an episode whose items have no products gets no shelf" do
    ShopCatalog.stub(:products, [].freeze) do
      get episode_path(episodes(:one))
      assert_response :success
      assert_select ".shop-shelf", 0
    end
  end

  # --- survivor page --------------------------------------------------------

  test "a survivor's shelf shows only what they brought, not what production gave" do
    with_products do
      get survivor_path(survivors(:one))
      assert_response :success
      assert_select ".shop-shelf h2", text: "Shop the Gear Test Brought"
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot)
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@knife), 0
      assert_no_match(/Given Knife/, response.body)
      assert_select ".shop-specific", text: "Used by Test Survivor A"
    end
  end

  test "a survivor who only was given gear gets no shelf" do
    with_products do
      get survivor_path(survivors(:two))
      assert_response :success
      assert_select ".shop-shelf", 0
    end
  end

  # --- country page ---------------------------------------------------------

  test "a country page shows shop cards for gear used in that country only" do
    with_products do
      get by_country_episodes_path("Costa Rica")   # episode one: pot brought, knife given
      assert_response :success
      assert_select ".shop-shelf h2", text: "Shop the Gear Used in Costa Rica"
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot, country: "Costa Rica")
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@knife, country: "Costa Rica")
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@salt, country: "Costa Rica"), 0   # found, not used
      assert_select ".shop-shelf li.shop-product", text: /Given Knife/

      get by_country_episodes_path("South Africa") # episode two: pot given, no knife
      assert_select ".shop-shelf h2", text: "Shop the Gear Used in South Africa"
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@pot, country: "South Africa")
      assert_select ".shop-shelf .shop-shelf-item a[href=?]", item_path(@knife, country: "South Africa"), 0
      assert_no_match(/Given Knife/, response.body)
    end
  end

  test "country matching ignores case, and products naming a local episode or survivor are labelled" do
    with_products do
      get by_country_episodes_path("costa rica")
      assert_select ".shop-shelf h2", text: "Shop the Gear Used in costa rica"
      assert_select ".shop-specific", text: "Seen in costa rica"
      assert_select ".shop-specific", text: "Used by Test Survivor A"
    end
  end

  test "a country's capped items link to the item page filtered to that country" do
    with_products do
      get by_country_episodes_path("Costa Rica")
      pots = css_select(".shop-shelf li.shop-product").select { |li| li.text.include?("Pot") }
      assert_equal 3, pots.size   # the country shelf shows 3 per item
      assert_select ".shop-shelf a[href=?]", item_path(@pot, country: "Costa Rica"), text: "see all"
    end
  end

  test "a country with no catalogued gear gets no shelf" do
    with_products do
      get by_country_episodes_path("Peru")
      assert_response :success
      assert_select ".shop-shelf", 0
    end
  end

  # --- ShopShelf ------------------------------------------------------------

  test "ShopShelf can rank items by use and cap how many it shows" do
    holders = { @pot => ["A"], @knife => %w[A B C], @salt => %w[A B] }
    with_products do
      shelf = ShopShelf.build(holders: holders, rank: holders.transform_values(&:size), max_groups: 2)
      assert_equal %w[knife salt], shelf.groups.map { |g| g.item.name }
      assert_equal 1, shelf.hidden_groups
      plain = ShopShelf.build(holders: holders)
      assert_equal %w[knife pot salt], plain.groups.map { |g| g.item.name }
      assert_equal 0, plain.hidden_groups
    end
  end

  test "ShopShelf labels products that name any of several episodes" do
    with_products do
      shelf = ShopShelf.build(holders: { @pot => [] }, episodes: [episodes(:one), episodes(:two)], episode_label: "Seen in Costa Rica")
      assert_equal "Seen in Costa Rica", shelf.groups.first.entries.first.label
    end
  end

  # --- ShopShelf (single episode) --------------------------------------------

  test "ShopShelf ranks specific products first and ignores items with no products" do
    with_products do
      shelf = ShopShelf.build(holders: { @pot => ["Test Survivor A"], @salt => [], Item.create!(name: "nothing") => [] },
                              episode: episodes(:one))
      assert_equal %w[pot salt], shelf.groups.map { |g| g.item.name }
      pot = shelf.groups.first
      assert_equal 6, pot.total
      assert_equal 2, pot.hidden
      assert_equal "Seen in this episode", pot.entries.first.label
      assert_equal "Used by Test Survivor A", pot.entries.second.label
      assert_nil pot.entries.last.label
    end
  end
end
