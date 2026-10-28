require "test_helper"
require "minitest/mock"

class Admin::ShopControllerTest < ActionDispatch::IntegrationTest
  PRODUCTS = [
    { item: "pot", category: "pot", product: "CanCooker Jr.", brand: "CanCooker", match: "likely",
      image: "https://m.media-amazon.com/images/I/abc._AC_SL500_.jpg",
      used_by: "Season 8", evidence_url: "https://example.com/e", evidence: "Fans say so",
      more_sources: ["https://example.com/e2"],
      buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B0B74MT6VM", asin: "B0B74MT6VM" },
            { store: "cancooker.com", url: "https://www.cancooker.com/" }] },
    { item: "", category: "blade", product: "Gator Machete", brand: "Gerber", match: "confirmed",
      buy: [{ store: "rei.com", url: "https://www.rei.com/x" }] },
    { item: "", category: "media", product: "Season 19", brand: "Discovery", match: "confirmed",
      buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B0GLV8K4K3", asin: "B0GLV8K4K3" }] }
  ].map(&:with_indifferent_access).freeze

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def with_products(list = PRODUCTS, &block) = ShopCatalog.stub(:products, list, &block)

  # --- access -------------------------------------------------------------

  test "a signed-out visitor is sent away" do
    get admin_shop_path
    assert_redirected_to root_path
  end

  test "a regular user is sent away" do
    sign_in(users(:one))
    get admin_shop_path
    assert_redirected_to root_path
  end

  test "an episode editor, who is not a full admin, is sent away" do
    editor = users(:admin)
    editor.update_columns(role: User.roles[:episode_editor])
    sign_in(editor)
    get admin_shop_path
    assert_redirected_to admin_episodes_path
  end

  test "there is no public /shop page" do
    sign_in(users(:admin))
    get "/shop"
    assert_response :not_found
  end

  # --- page ---------------------------------------------------------------

  test "an admin sees products grouped by category with buy links" do
    sign_in(users(:admin))
    with_products do
      get admin_shop_path
      assert_response :success
      assert_select "li.shop-product", 3
      assert_select "#shop-count", /3 of 3 products.*2 with an Amazon listing/m
      assert_select "a.btn-warning[href=?]", "https://www.amazon.com/dp/B0B74MT6VM", text: "View on Amazon"
      assert_select "a[href='https://www.rei.com/x']", text: /rei\.com/
      assert_select "a[href='https://example.com/e2']", text: "Source 2"
      assert_select "meta[name=robots][content*=noindex]"
      assert_select "nav[aria-label=Admin] a[href=?]", admin_shop_path, text: "Shop"
    end
  end

  test "books and merch sort after the gear and are labelled official" do
    sign_in(users(:admin))
    with_products do
      get admin_shop_path
      headers = css_select(".card-header").map { |h| h.text.strip }
      assert headers.index { |h| h.start_with?("Media") } > headers.index { |h| h.start_with?("Pot") }
      assert_select "li.shop-product .badge", text: "Official / cast-made"
    end
  end

  test "outbound links are marked sponsored and nofollow" do
    sign_in(users(:admin))
    with_products do
      get admin_shop_path
      assert_select "li.shop-product a.btn[rel~=sponsored][rel~=nofollow][target=_blank]", minimum: 3
    end
  end

  test "filters by category, confidence, text and Amazon" do
    sign_in(users(:admin))
    with_products do
      get admin_shop_path, params: { category: "blade" }
      assert_select "li.shop-product", 1
      get admin_shop_path, params: { match: "likely" }
      assert_select "li.shop-product", text: /CanCooker/
      get admin_shop_path, params: { q: "gerber" }
      assert_select "li.shop-product", 1
      get admin_shop_path, params: { amazon: "1" }
      assert_select "li.shop-product", 2
      get admin_shop_path, params: { q: "nothing matches this" }
      assert_select "li.shop-product", 0
      assert_select ".alert", /No products match/
    end
  end

  test "an item that exists on the site links back to its item page" do
    sign_in(users(:admin))
    item = Item.create!(name: "pot")
    with_products do
      get admin_shop_path
      assert_select "a[href=?]", item_path(item)
    end
  end

  test "each card shows its product photo, or a placeholder when there is none" do
    sign_in(users(:admin))
    with_products do
      get admin_shop_path
      assert_select "li.shop-product img[src=?][alt=?]", "https://m.media-amazon.com/images/I/abc._AC_SL500_.jpg", "CanCooker Jr."
      assert_select "li.shop-product", 3
      assert_select "li.shop-product img", 1
      assert_select "li.shop-product .shop-product-image", 3
    end
  end

  test "the associate tag is appended to amazon links only when configured" do
    link = PRODUCTS[0][:buy][0]
    assert_equal "https://www.amazon.com/dp/B0B74MT6VM", ShopCatalog.buy_url(link, tag: nil)
    assert_equal "https://www.amazon.com/dp/B0B74MT6VM?tag=nanda-20", ShopCatalog.buy_url(link, tag: "nanda-20")
    assert_equal "https://www.cancooker.com/", ShopCatalog.buy_url(PRODUCTS[0][:buy][1], tag: "nanda-20")
  end
end

# Guards the hand-edited data file, which is where bad links would sneak in.
class ShopCatalogDataTest < ActiveSupport::TestCase
  REQUIRED = %w[category product match evidence_url buy].freeze

  test "every product has the required fields and a valid match level" do
    ShopCatalog.products.each do |p|
      REQUIRED.each { |k| assert p[k].present?, "#{p[:product].inspect} is missing #{k}" }
      assert_includes ShopCatalog::MATCHES, p[:match], "#{p[:product]}: bad match #{p[:match].inspect}"
      assert p[:buy].is_a?(Array) && p[:buy].any?, "#{p[:product]} has no buy links"
    end
  end

  test "product images are https image urls" do
    with_image = ShopCatalog.products.select { |p| p[:image].present? }
    assert with_image.size > 100, "expected most products to have a photo"
    with_image.each do |p|
      assert_match %r{\Ahttps://\S+\z}, p[:image], "#{p[:product]}: bad image url"
    end
  end

  test "amazon links are well formed and agree with their ASIN" do
    ShopCatalog.products.each do |p|
      p[:buy].each do |l|
        assert l[:url].to_s.match?(%r{\Ahttps?://}), "#{p[:product]}: bad url #{l[:url].inspect}"
        next unless ShopCatalog.amazon?(l) && l[:asin].present?
        assert_match(/\A[A-Z0-9]{10}\z/, l[:asin], "#{p[:product]}: bad ASIN")
        assert_match(%r{/(dp|gp/product)/#{l[:asin]}}, l[:url], "#{p[:product]}: url does not match ASIN")
      end
    end
  end

  test "no product is listed twice" do
    keys = ShopCatalog.products.map { |p| [p[:brand].to_s.downcase, p[:product].to_s.downcase] }
    assert_equal keys.uniq.size, keys.size, "duplicates: #{keys.tally.select { |_, n| n > 1 }.keys.inspect}"
  end

  test "no ASIN is attached to two different products" do
    seen = {}
    ShopCatalog.products.each do |p|
      p[:buy].each do |l|
        next unless l[:asin]
        other = seen[l[:asin]]
        assert other.nil? || other == p[:product], "#{l[:asin]} is on both #{other.inspect} and #{p[:product].inspect}"
        seen[l[:asin]] = p[:product]
      end
    end
  end

  test "no internal QA text leaks into visitor-facing fields" do
    ShopCatalog.products.each do |p|
      text = [p[:used_by], p[:evidence], p[:notes]].join(" ")
      assert_no_match(/\bB0[A-Z0-9]{8}\b|MTJS/, text, "#{p[:product]} has internal text")
    end
  end
end
