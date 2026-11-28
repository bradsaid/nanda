require "test_helper"

# Homepage LCP: the header banner is the largest above-the-fold image. It is fetched early
# and with high priority, everything else below the fold is lazy, and nothing in <head>
# blocks the parser.
class HomeLcpTest < ActionDispatch::IntegrationTest
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")

  setup do
    [ survivors(:one), survivors(:two) ].each do |s|
      s.avatar.attach(io: StringIO.new(PNG), filename: "face.png", content_type: "image/png")
    end
    get "/"
    @doc = Nokogiri::HTML(response.body)
  end

  test "the banner img is eager, high priority, sized and the only high-priority image" do
    img = @doc.at_css("header picture img.site-banner")
    assert_equal "eager", img["loading"]
    assert_equal "high", img["fetchpriority"]
    assert_equal "1200", img["width"]
    assert_equal "674", img["height"]
    assert_equal [ img ], @doc.css("img[fetchpriority=high]").to_a
    assert_equal [ img ], @doc.css("img[loading=eager]").to_a, "no other image on / may be eager"
  end

  test "the preload mirrors the picture's AVIF source srcset and sizes" do
    link   = @doc.at_css("head link[rel=preload][as=image]")
    source = @doc.at_css("header picture source[type='image/avif']")
    assert_equal source["srcset"], link["imagesrcset"]
    assert_equal source["sizes"],  link["imagesizes"]
    assert_equal "image/avif", link["type"]
    assert_equal "high", link["fetchpriority"]
  end

  test "critical preloads (banner, font, CSS) come before the importmap and its modulepreloads" do
    kids = @doc.at_css("head").element_children
    banner  = kids.index { |e| e.name == "link" && e["as"] == "image" }
    font    = kids.index { |e| e.name == "link" && e["as"] == "font" }
    css     = kids.index { |e| e.name == "link" && e["as"] == "style" }
    importm = kids.index { |e| e.name == "script" && e["type"] == "importmap" }
    firstmp = kids.index { |e| e.name == "link" && e["rel"] == "modulepreload" }
    [ banner, font, css ].each { |i| assert i, "missing a critical preload" }
    assert_operator [ banner, font, css ].max, :<, importm
    assert_operator importm, :<, firstmp
  end

  test "every <img> below the banner is lazy with explicit dimensions" do
    imgs = @doc.css("img").reject { |i| i["class"].to_s.include?("site-banner") }
    assert imgs.any?, "expected survivor avatars on the home page"
    imgs.each do |i|
      assert_equal "lazy", i["loading"], i.to_s
      assert i["width"].present? && i["height"].present?, "missing dimensions: #{i}"
    end
  end

  test "no external script in <head> is parser-blocking" do
    @doc.css("head script[src]").each do |s|
      assert s.key?("async") || s.key?("defer") || s["type"] == "module",
             "render-blocking head script: #{s['src']}"
    end
  end

  test "no stylesheet in <head> comes from a third-party origin" do
    @doc.css("head link[rel=stylesheet]").each do |l|
      assert l["href"].start_with?("/"), "third-party stylesheet: #{l['href']}"
    end
  end
end
