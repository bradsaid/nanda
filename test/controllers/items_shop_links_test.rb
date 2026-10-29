require "test_helper"
require "minitest/mock"

# The item page shows the item's shop products to everyone, with the affiliate disclosure.
class ItemsShopLinksTest < ActionDispatch::IntegrationTest
  PRODUCTS = [
    { item: "pot", category: "pot", product: "Likely Pot", brand: "A", match: "likely", evidence_url: "https://e.com/1",
      buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B00B22G0PO", asin: "B00B22G0PO" }] },
    { item: "pot", category: "pot", product: "Confirmed Pot", brand: "B", match: "confirmed", evidence_url: "https://e.com/2",
      buy: [{ store: "cancooker.com", url: "https://www.cancooker.com/" }] },
    { item: "knife", category: "blade", product: "A Knife", brand: "C", match: "similar", evidence_url: "https://e.com/3",
      buy: [{ store: "x.com", url: "https://x.com/k" }] }
  ].map(&:with_indifferent_access).freeze

  setup { @pot = Item.create!(name: "pot") }

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def with_products(&block) = ShopCatalog.stub(:products, PRODUCTS, &block)

  test "an item shows only its own products, strongest evidence first" do
    with_products do
      get item_path(@pot)
      assert_response :success
      assert_select "#item-shop li.shop-product", 2
      names = css_select("#item-shop li.shop-product .fw-semibold").map { |n| n.text.strip }
      assert_match(/Confirmed Pot/, names.first)
      assert_match(/Likely Pot/, names.last)
      assert_select "#item-shop a[href=?]", go_path(ShopCatalog.anchor(PRODUCTS[0]), from: "item"), text: "View on Amazon"
      assert_no_match(/A Knife/, response.body)
    end
  end

  test "the shop card sits above the Given and Brought lists and the country table" do
    with_products do
      get item_path(@pot)
      body = response.body
      shop = body.index('id="item-shop"')
      assert shop, "shop card missing"
      ["Given — Episodes", "Brought — Episodes", "By Country"].each do |heading|
        at = body.index(heading)
        assert at, "#{heading} missing"
        assert_operator shop, :<, at, "shop card should come before #{heading}"
      end
    end
  end

  test "a signed-out visitor sees the shop card with the disclosure" do
    with_products do
      get item_path(@pot)
      assert_response :success
      assert_select "#item-shop li.shop-product", 2
      assert_select "#item-shop .shop-disclosure", /Amazon Associate/
    end
  end

  test "a regular user sees it too" do
    sign_in(users(:one))
    with_products do
      get item_path(@pot)
      assert_select "#item-shop li.shop-product", 2
    end
  end

  test "an item with no products shows no shop card" do
    lonely = Item.create!(name: "salt")
    with_products do
      get item_path(lonely)
      assert_response :success
      assert_select "#item-shop", 0
    end
  end

  test "ShopCatalog.for_item matches the name case-insensitively" do
    with_products { assert_equal 2, ShopCatalog.for_item("POT").size }
  end
end
