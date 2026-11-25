require "test_helper"

class SiteBannerTest < ActionDispatch::IntegrationTest
  setup do
    get "/"
    @doc = Nokogiri::HTML(response.body)
  end

  test "banner is a picture with AVIF and WebP sources at 400/800/1200w" do
    picture = @doc.at_css("header picture")
    assert picture, "expected a <picture> in the header"

    { "image/avif" => "avif", "image/webp" => "webp" }.each do |type, ext|
      source = picture.at_css("source[type='#{type}']")
      assert source, "missing #{type} source"
      [ 400, 800, 1200 ].each do |w|
        assert_match(%r{/assets/NAKED-#{w}-[0-9a-f]+\.#{ext} #{w}w}, source["srcset"])
      end
      assert source["sizes"].present?
    end
  end

  test "fallback img keeps the PNG, has dimensions, is high priority and is not lazy" do
    img = @doc.at_css("header picture img.site-banner")
    assert img
    assert_match(%r{/assets/NAKED-[0-9a-f]+\.png}, img["src"])
    assert_equal "1200", img["width"]
    assert_equal "674",  img["height"]
    assert_equal "high", img["fetchpriority"]
    assert_equal "async", img["decoding"]
    assert_not_equal "lazy", img["loading"]
    assert_equal "Naked and Afraid Fan Database", img["alt"]
  end

  test "head preloads the responsive banner, not the 494 KB PNG" do
    preloads = @doc.css("head link[rel=preload][as=image]")
    assert_equal 1, preloads.size
    link = preloads.first
    assert_match(/NAKED-400-.*avif 400w/, link["imagesrcset"])
    assert link["imagesizes"].present?
    assert_equal "high", link["fetchpriority"]
    assert_nil link["href"]
    assert_no_match(%r{/assets/NAKED-[0-9a-f]+\.png}, @doc.css("head link").map(&:to_s).join)
  end

  test "variant files exist and are far smaller than the original PNG" do
    dir = Rails.root.join("app/assets/images")
    png = File.size(dir.join("NAKED.png"))
    %w[avif webp].each do |ext|
      [ 400, 800, 1200 ].each do |w|
        path = dir.join("NAKED-#{w}.#{ext}")
        assert path.exist?, "#{path} missing"
        assert_operator File.size(path), :<, png / 3
      end
    end
  end
end
