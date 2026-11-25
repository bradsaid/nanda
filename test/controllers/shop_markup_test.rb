require "test_helper"
require "minitest/mock"

# /shop keeps its whole catalog on one page: other pages deep-link to #p-<anchor> cards and
# the category jump links point at #<category>-products. So it is not paginated; off-screen
# cards are skipped by the browser instead (content-visibility on .shop-catalog > .shop-product).
class ShopMarkupTest < ActionDispatch::IntegrationTest
  PRODUCTS = [
    { item: "", category: "blade", product: "Gator Machete", brand: "Gerber", match: "confirmed",
      buy: [{ store: "rei.com", url: "https://www.rei.com/x" }] },
    { item: "", category: "pot", product: "CanCooker Jr.", brand: "CanCooker", match: "likely",
      buy: [{ store: "amazon", url: "https://www.amazon.com/dp/B0B74MT6VM", asin: "B0B74MT6VM" }] }
  ].map(&:with_indifferent_access).freeze

  test "every card sits in a .shop-catalog list, with category jump links and card anchors intact" do
    ShopCatalog.stub(:products, PRODUCTS) do
      get shop_path
      assert_response :success
      assert_select "ul.shop-catalog > li.shop-product", 2
      assert_select "nav.shop-jump a[href='#blade-products']"
      assert_equal 1, css_select("#blade-products ul.shop-catalog li.shop-product[id='#{ShopCatalog.anchor(PRODUCTS[0])}']").size
      assert_select "ul.pagination", false
    end
  end

  test "the stylesheet defers rendering of off-screen catalog cards" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_match(/\.shop-catalog > \.shop-product\s*\{[^}]*content-visibility:\s*auto/m, css)
  end
end
