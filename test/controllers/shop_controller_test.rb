require "test_helper"
require "minitest/mock"

class ShopControllerTest < ActionDispatch::IntegrationTest
  PRODUCTS = [
    { item: "pot", category: "pot", product: "CanCooker Jr.", brand: "CanCooker", match: "likely",
      image: "https://m.media-amazon.com/images/I/abc._AC_SL500_.jpg",
      survivors: ["Test Survivor A", "Nobody Here"],
      episodes: [{ series: "TestSeriesA", season: 1, title: "Test Episode A" },
                 { series: "TestSeriesA", season: 1, title: "No Such Episode" }],
      used_by: "Season 8", evidence_url: "https://example.com/e", evidence: "Fans say so",
      more_sources: ["https://example.com/e2"],
      buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B0B74MT6VM", asin: "B0B74MT6VM" },
            { store: "cancooker.com", url: "https://www.cancooker.com/" }] },
    { item: "", category: "blade", product: "Gator Machete", brand: "Gerber", match: "confirmed",
      buy: [{ store: "rei.com", url: "https://www.rei.com/x" }] },
    { item: "", category: "media", product: "Season 19", brand: "Discovery", match: "confirmed",
      buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B0GLV8K4K3", asin: "B0GLV8K4K3" }] }
  ].map(&:with_indifferent_access).freeze

  def with_products(list = PRODUCTS, &block) = ShopCatalog.stub(:products, list, &block)

  # --- access -------------------------------------------------------------

  test "anyone can see the shop, signed out, with the affiliate disclosure" do
    with_products do
      get shop_path
      assert_response :success
      assert_select "li.shop-product", 3
      assert_select "#shop-count", /3 of 3 products.*2 with an Amazon listing/m
      assert_select ".shop-disclosure", /As an Amazon Associate I earn from qualifying purchases/
    end
  end

  test "the old admin URL redirects to the public shop" do
    get "/admin/shop"
    assert_redirected_to "/shop"
    assert_response :moved_permanently
  end

  test "the main shop page is indexable with a canonical URL, filtered views are not" do
    with_products do
      get shop_path
      assert_select "meta[name=robots]", 0
      assert_select "link[rel=canonical][href$=?]", "/shop"
      get shop_path, params: { category: "blade" }
      assert_select "meta[name=robots][content=?]", "noindex, follow"
      assert_select "link[rel=canonical][href$=?]", "/shop"
    end
  end

  test "the footer links to the shop and carries the disclosure on every page" do
    get root_path
    assert_select "footer a[href=?]", shop_path, text: "Shop"
    assert_select "footer .footer-affiliate-disclosure", /Amazon Associate/
  end

  test "the shop is in the sitemap" do
    assert_match(/add shop_path/, File.read(Rails.root.join("config/sitemap.rb")))
  end

  # --- page ---------------------------------------------------------------

  test "products are grouped by category with buy links" do
    with_products do
      get shop_path
      assert_response :success
      assert_select "a.btn-warning[href=?]", "https://www.amazon.com/dp/B0B74MT6VM", text: "View on Amazon"
      assert_select "a[href='https://www.rei.com/x']", text: /rei\.com/
      assert_select "a[href='https://example.com/e2']", text: "Source 2"
    end
  end

  test "maintainer notes are never shown publicly" do
    list = [PRODUCTS[0].merge(notes: "SECRET maintainer remark")]
    with_products(list) do
      get shop_path
      assert_select "li.shop-product", 1
      assert_no_match(/SECRET maintainer remark/, response.body)
    end
  end

  test "books and merch sort after the gear and are labelled official" do
    with_products do
      get shop_path
      headers = css_select(".card-header").map { |h| h.text.strip }
      assert headers.index { |h| h.start_with?("Media") } > headers.index { |h| h.start_with?("Pot") }
      assert_select "li.shop-product .badge", text: "Official / cast-made"
    end
  end

  test "outbound links are marked sponsored and nofollow" do
    with_products do
      get shop_path
      assert_select "li.shop-product a.btn[rel~=sponsored][rel~=nofollow][target=_blank]", minimum: 3
    end
  end

  test "filters by category, confidence, text and Amazon" do
    with_products do
      get shop_path, params: { category: "blade" }
      assert_select "li.shop-product", 1
      get shop_path, params: { match: "likely" }
      assert_select "li.shop-product", text: /CanCooker/
      get shop_path, params: { q: "gerber" }
      assert_select "li.shop-product", 1
      get shop_path, params: { amazon: "1" }
      assert_select "li.shop-product", 2
      get shop_path, params: { q: "nothing matches this" }
      assert_select "li.shop-product", 0
      assert_select ".alert", /No products match/
    end
  end

  test "an item that exists on the site links back to its item page" do
    item = Item.create!(name: "pot")
    with_products do
      get shop_path
      assert_select "a[href=?]", item_path(item)
    end
  end

  test "each card shows its product photo, or a placeholder when there is none" do
    with_products do
      get shop_path
      assert_select "li.shop-product img[src=?][alt=?]", "https://m.media-amazon.com/images/I/abc._AC_SL500_.jpg", "CanCooker Jr."
      assert_select "li.shop-product", 3
      assert_select "li.shop-product img", 1
      assert_select "li.shop-product .shop-product-image", 3
    end
  end

  test "cards link to the survivor bios and episodes they name, skipping any that no longer exist" do
    with_products do
      get shop_path
      assert_select ".shop-survivors a[href=?]", survivor_path(survivors(:one)), text: "Test Survivor A"
      assert_select ".shop-survivors a", 1
      assert_select ".shop-episodes a[href=?]", episode_path(episodes(:one)), text: "Test Episode A (TestSeriesA S1)"
      assert_select ".shop-episodes a", 1
      # products that name nobody get no empty "Survivors:" line
      assert_select ".shop-survivors", 1
      assert_select ".shop-episodes", 1
    end
  end

  test "the same survivor and episode links appear on the item page" do
    Item.create!(name: "pot")
    with_products do
      get item_path(Item.find_by!(name: "pot"))
      assert_select "#item-shop .shop-survivors a[href=?]", survivor_path(survivors(:one))
      assert_select "#item-shop .shop-episodes a[href=?]", episode_path(episodes(:one))
    end
  end

  test "ShopLinks resolves survivor names and episode titles to records" do
    links = ShopLinks.build(PRODUCTS)
    assert_equal [survivors(:one)], links.survivors_for(PRODUCTS[0])
    assert_equal [episodes(:one)], links.episodes_for(PRODUCTS[0])
    assert_empty links.survivors_for(PRODUCTS[1])
    assert_empty links.episodes_for(PRODUCTS[1])
  end

  test "store names drop their parenthetical, which becomes a caption under the button" do
    long = { store: "jblspearguns.com (Shaka Hybrid Carbon, a different model)", url: "https://jblspearguns.com/x" }
    assert_equal "jblspearguns.com", ShopCatalog.store_name(long)
    assert_equal "Shaka Hybrid Carbon, a different model", ShopCatalog.store_note(long)
    etsy = { store: "etsy (ArcticPines listing, 'From Naked and Afraid')", url: "https://etsy.com/x" }
    assert_equal "Etsy", ShopCatalog.store_name(etsy)
    plain = { store: "rei.com", url: "https://rei.com" }
    assert_equal "rei.com", ShopCatalog.store_name(plain)
    assert_nil ShopCatalog.store_note(plain)
    products = [PRODUCTS[1].merge(buy: [long])]
    with_products(products) do
      get shop_path
      assert_select "a.btn", text: "Buy at jblspearguns.com"
      assert_select ".shop-buy-note", text: "Shaka Hybrid Carbon, a different model"
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

  test "visitor-facing text does not name the research source site" do
    ShopCatalog.products.each do |p|
      text = [p[:used_by], p[:product], p[:brand]].join(" ")
      assert_no_match(/morethanjustsurviving|mtjs/i, text, "#{p[:product]}: used_by leaks the research source")
    end
  end

  test "survivor and episode references are well formed" do
    refs = 0
    ShopCatalog.products.each do |p|
      Array(p[:survivors]).each { |n| assert n.is_a?(String) && n.present?, "#{p[:product]}: bad survivor #{n.inspect}"; refs += 1 }
      Array(p[:episodes]).each do |e|
        assert e[:series].present? && e[:season].is_a?(Integer) && e[:title].present?, "#{p[:product]}: bad episode #{e.inspect}"
        refs += 1
      end
    end
    assert refs > 100, "expected the catalog to carry survivor and episode links"
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
