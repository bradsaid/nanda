require "test_helper"
require "minitest/mock"

# /go/:anchor counts a click on a buy button, then redirects to the catalog's own URL.
class AffiliateRedirectsTest < ActionDispatch::IntegrationTest
  TAG = "nanda-test-20".freeze
  BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
               "(KHTML, like Gecko) Chrome/140.0 Safari/537.36".freeze
  IPHONE_UA  = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " \
               "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1".freeze

  PRODUCTS = [
    { item: "pot", category: "pot", product: "Named Pot", brand: "B", match: "confirmed", evidence_url: "https://e.com/n",
      buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B000000001", asin: "B000000001" }] },
    { item: "knife", category: "blade", product: "Elsewhere Knife", brand: "C", match: "likely", evidence_url: "https://e.com/k",
      buy: [{ store: "rei.com", url: "https://www.rei.com/k" }, { store: "x.com", url: "https://x.com/k" }] }
  ].map(&:with_indifferent_access).freeze

  POT   = ShopCatalog.anchor(PRODUCTS[0])
  KNIFE = ShopCatalog.anchor(PRODUCTS[1])

  def with_products(&block) = ShopCatalog.stub(:products, PRODUCTS, &block)

  def with_tag(tag = TAG)
    was = ENV["AMAZON_ASSOCIATE_TAG"]
    ENV["AMAZON_ASSOCIATE_TAG"] = tag
    yield
  ensure
    ENV["AMAZON_ASSOCIATE_TAG"] = was
  end

  def click(path, ua: BROWSER_UA, headers: {})
    get path, headers: { "HTTP_USER_AGENT" => ua }.merge(headers)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  # --- redirect ---------------------------------------------------------------

  test "redirects to the tagged Amazon URL with no caching" do
    with_products do
      with_tag do
        click go_path(POT, from: "shop")
        assert_response :found
        assert_equal "https://www.amazon.com/dp/B000000001?tag=#{TAG}", response.location
        assert_includes response.location, "tag="
        assert_match(/no-store/, response.headers["Cache-Control"])
      end
    end
  end

  test "an unknown anchor is a 404 and nothing is recorded" do
    with_products do
      assert_no_difference "AffiliateClick.count" do
        click go_path("p-not-a-product")
        assert_response :not_found
      end
    end
  end

  test "a raw url parameter is ignored: the destination only ever comes from the catalog" do
    with_products do
      click go_path(POT, url: "https://evil.example/phish", to: "https://evil.example/", store: "https://evil.example/")
      assert_response :found
      assert_match %r{\Ahttps://www\.amazon\.com/dp/B000000001}, response.location
      assert_no_match(/evil/, response.location)
    end
  end

  test "a store index picks that buy link, and an out-of-range index is a 404" do
    with_products do
      click go_path(KNIFE)
      assert_equal "https://www.rei.com/k", response.location
      click go_path(KNIFE, store: 1)
      assert_equal "https://x.com/k", response.location
      click go_path(KNIFE, store: 2)
      assert_response :not_found
    end
  end

  # --- recording --------------------------------------------------------------

  test "a click row is created with the placement and product details" do
    with_products do
      assert_difference "AffiliateClick.count", 1 do
        click go_path(POT, from: "guide"), headers: { "HTTP_REFERER" => "http://www.example.com/shop/guides/pot?x=1" }
      end
    end
    c = AffiliateClick.order(:id).last
    assert_equal POT, c.product_anchor
    assert_equal "Named Pot", c.product_name
    assert_equal "pot", c.item
    assert_equal "amazon", c.store
    assert_equal "www.amazon.com", c.destination_host
    assert_equal "guide", c.placement
    assert_equal "/shop/guides/pot", c.referring_path   # path only, no query
    assert_equal false, c.is_mobile
  end

  test "a non-Amazon click records the store name, and a phone is flagged mobile" do
    with_products do
      click go_path(KNIFE, store: 1, from: "item"), ua: IPHONE_UA
    end
    c = AffiliateClick.order(:id).last
    assert_equal "x.com", c.store
    assert_equal "x.com", c.destination_host
    assert_equal true, c.is_mobile
  end

  test "a junk placement is dropped and an external referrer is not stored" do
    with_products do
      click go_path(POT, from: "<script>alert(1)</script>"), headers: { "HTTP_REFERER" => "https://elsewhere.example/page" }
    end
    c = AffiliateClick.order(:id).last
    assert_nil c.placement
    assert_nil c.referring_path
  end

  test "bots and blank user agents are redirected but not counted" do
    with_products do
      assert_no_difference "AffiliateClick.count" do
        [ "Googlebot/2.1 (+http://www.google.com/bot.html)", "AhrefsBot/7.0", "curl/8.4.0", "" ].each do |ua|
          click go_path(POT), ua: ua
          assert_response :found, "expected a redirect for #{ua.inspect}"
          assert_match %r{amazon\.com/dp/B000000001}, response.location
        end
      end
    end
  end

  test "no IP address or user agent is stored" do
    assert_empty AffiliateClick.column_names & %w[ip_address remote_ip user_agent visitor_id session_id user_id]
    with_products { click go_path(POT, from: "shop"), headers: { "REMOTE_ADDR" => "203.0.113.77" } }
    stored = AffiliateClick.order(:id).last.attributes.values.map(&:to_s).join(" ")
    assert_no_match(/203\.0\.113\.77/, stored)
    assert_no_match(/Chrome/, stored)
  end

  test "a database error does not break the redirect" do
    with_products do
      AffiliateClick.stub(:create!, ->(*) { raise ActiveRecord::StatementInvalid, "boom" }) do
        click go_path(POT)
        assert_response :found
        assert_match %r{amazon\.com/dp/B000000001}, response.location
      end
    end
  end

  test "a redirect is not recorded as a page view" do
    with_products do
      assert_no_difference "PageView.count" do
        click go_path(POT)
      end
    end
  end

  # --- robots -----------------------------------------------------------------

  test "robots.txt disallows /go/" do
    assert_match(%r{^Disallow: /go/$}, File.read(Rails.root.join("public/robots.txt")))
  end

  # --- cards link to /go/ -----------------------------------------------------

  test "shop page buttons point at the tracked redirect and keep their rel and target" do
    with_products do
      get shop_path
      assert_select "li.shop-product a.btn-warning[href=?][target=_blank][rel~=sponsored][rel~=noopener][rel~=noreferrer][rel~=nofollow]",
                    go_path(POT, from: "shop"), text: "View on Amazon"
      assert_select "li.shop-product a.btn[href=?]", go_path(KNIFE, from: "shop"), text: "Buy at rei.com"
      assert_select "li.shop-product a.btn[href=?]", go_path(KNIFE, from: "shop", store: 1), text: "Buy at x.com"
      assert_no_match(/amazon\.com\/dp\/B000000001/, css_select(".shop-product-actions").to_s)
    end
  end

  test "an item page button carries the item placement" do
    Item.create!(name: "pot")
    with_products do
      get item_path(Item.find_by(name: "pot"))
      assert_select "#item-shop a.btn-warning[href=?]", go_path(POT, from: "item")
    end
  end

  test "a gear guide button carries the guide placement and follows through to the tagged URL" do
    product = ShopCatalog.products.find { |p| p[:category] == "blade" && ShopCatalog.amazon_link(p) }
    get shop_guide_path("blade")
    assert_select "li.shop-product a.btn-warning[href^='/go/'][href*='from=guide']", minimum: 1
    with_tag do
      click go_path(ShopCatalog.anchor(product), from: "guide")
      assert_response :found
      assert_includes response.location, "tag=#{TAG}"
    end
  end

  # --- admin ------------------------------------------------------------------

  test "the admin page is not available to the public or to ordinary members" do
    get admin_affiliate_clicks_path
    assert_redirected_to root_path
    sign_in users(:one)
    get admin_affiliate_clicks_path
    assert_redirected_to root_path
  end

  test "an admin sees totals, top products, placements and recent clicks" do
    AffiliateClick.create!(product_anchor: POT, product_name: "Named Pot", item: "pot", store: "amazon",
                           destination_host: "www.amazon.com", placement: "home", referring_path: "/")
    2.times do
      AffiliateClick.create!(product_anchor: KNIFE, product_name: "Elsewhere Knife", item: "knife", store: "rei.com",
                             destination_host: "www.rei.com", placement: "shop", referring_path: "/shop")
    end
    AffiliateClick.create!(product_anchor: POT, product_name: "Named Pot", placement: "shop", created_at: 10.days.ago)

    sign_in users(:admin)
    get admin_affiliate_clicks_path
    assert_response :success
    assert_select "h1", "Affiliate Clicks"
    counts = css_select(".card .h4").map { |n| n.text.strip }
    assert_equal %w[3 3 4 4], counts   # 24h, 7d, 30d, all time
    assert_select "td", text: "Elsewhere Knife"
    assert_select "td", text: "Named Pot"
    assert_select "td", text: "rei.com"
    assert_select "td", text: "home"
    assert_select "td", text: "/shop"
    assert_select "nav[aria-label=Admin] a[href=?]", admin_affiliate_clicks_path
  end
end
