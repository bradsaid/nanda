require "test_helper"
require "minitest/mock"

# Below-the-fold images lazy-load by default (config.action_view.image_loading);
# above-the-fold ones opt out with loading: "eager".
class ImageLoadingTest < ActionDispatch::IntegrationTest
  def img_tags(html) = html.scan(/<img\b[^>]*>/)

  test "image_tag defaults to lazy + async decoding" do
    html = ApplicationController.helpers.image_tag("NAKED.png", alt: "x")
    assert_includes html, 'loading="lazy"'
    assert_includes html, 'decoding="async"'
  end

  test "an explicit loading option wins and is never duplicated" do
    eager = ApplicationController.helpers.image_tag("NAKED.png", alt: "x", loading: "eager")
    assert_includes eager, 'loading="eager"'
    assert_no_match(/loading="lazy"/, eager)

    lazy = ApplicationController.helpers.image_tag("NAKED.png", alt: "x", loading: "lazy")
    assert_equal 1, lazy.scan("loading=").size
    assert_equal 1, lazy.scan("decoding=").size
  end

  test "the header banner is never lazy-loaded" do
    get "/"
    banner = img_tags(response.body).find { |t| t.include?("site-banner") }
    assert banner
    assert_no_match(/loading="lazy"/, banner)
    assert_includes banner, 'fetchpriority="high"'
  end

  test "no image on any page carries two loading attributes" do
    [ "/", "/survivors", "/episodes", "/locations", "/items", "/shop" ].each do |path|
      get path
      img_tags(response.body).each do |t|
        assert_operator t.scan(/\bloading=/).size, :<=, 1, "duplicate loading attr in #{t} on #{path}"
      end
    end
  end

  test "survivors grid avatars lazy-load" do
    get "/survivors"
    avatars = img_tags(response.body).select { |t| t.include?("avatar-portrait") }
    assert avatars.any?, "expected at least one survivor avatar"
    avatars.each { |t| assert_includes t, 'loading="lazy"' }
  end

  test "shop product images lazy-load" do
    products = [ { item: "pot", category: "pot", product: "CanCooker Jr.", brand: "CanCooker", match: "likely",
                   image: "https://m.media-amazon.com/images/I/abc._AC_SL500_.jpg",
                   buy: [ { store: "amazon", url: "https://www.amazon.com/dp/B0B74MT6VM", asin: "B0B74MT6VM" } ] } ].map(&:with_indifferent_access)
    ShopCatalog.stub(:products, products) do
      get "/shop"
    end
    tags = img_tags(response.body).select { |t| t.include?("media-amazon") }
    assert tags.any?
    tags.each do |t|
      assert_includes t, 'loading="lazy"'
      assert_includes t, 'decoding="async"'
    end
  end
end
