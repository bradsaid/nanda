require "test_helper"

# og:image / twitter:image on every page: exactly one of each, absolute, on the canonical host,
# with dimensions; survivors with an avatar get a non-expiring proxy URL, everything else the
# default site artwork.
class ShareImageTest < ActionDispatch::IntegrationTest
  ORIGIN = "https://www.nakedandafraidfan.com".freeze
  # 1x1 PNG
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")

  setup do
    ENV["FORUM_ENABLED"] = "true" # /forum is a 404 while the forum is dark
    create_podcast_survivors
  end

  # /podcasts looks survivors up by name and links to them; give it the ones it names.
  def create_podcast_survivors
    File.read(Rails.root.join("app/views/static_pages/podcasts.html.slim")).scan(/find_by\(full_name: "([^"]+)"\)/).flatten.uniq.each do |name|
      Survivor.find_or_create_by!(full_name: name)
    end
  end
  teardown { ENV["FORUM_ENABLED"] = nil }

  def meta(selector) = css_select(selector)

  def assert_share_image(path = nil)
    get path if path
    assert_response :success, "GET #{path}"
    og = meta('meta[property="og:image"]')
    tw = meta('meta[name="twitter:image"]')
    assert_equal 1, og.size, "og:image count on #{path}"
    assert_equal 1, tw.size, "twitter:image count on #{path}"
    assert og.first["content"].start_with?("#{ORIGIN}/"), "og:image not on canonical host: #{og.first['content']}"
    assert_equal og.first["content"], tw.first["content"]
    assert_match(/\A\d+\z/, meta('meta[property="og:image:width"]').first["content"])
    assert_match(/\A\d+\z/, meta('meta[property="og:image:height"]').first["content"])
    assert_equal 1, meta('meta[property="og:image:width"]').size
    assert_equal 1, meta('meta[property="og:image:height"]').size
    assert_predicate meta('meta[property="og:image:alt"]').first["content"], :present?
    assert_equal 1, meta('meta[name="twitter:card"]').size
    og.first["content"]
  end

  test "default share image is a fingerprinted absolute asset URL" do
    url = assert_share_image("/")
    assert_match %r{\A#{Regexp.escape(ORIGIN)}/assets/share-default-[0-9a-f]+\.jpg\z}, url
    assert_equal "1200", meta('meta[property="og:image:width"]').first["content"]
    assert_equal "630", meta('meta[property="og:image:height"]').first["content"]
    assert_equal "summary_large_image", meta('meta[name="twitter:card"]').first["content"]
  end

  test "the default share image file is 1200x630 and under 300 KB" do
    path = Rails.root.join("app/assets/images/share-default.jpg")
    assert_operator File.size(path), :<, 300 * 1024
    header = File.binread(path, 4096)
    # JPEG SOF0/SOF2 marker carries height then width
    sof = header.index(/\xFF[\xC0\xC2]/n)
    assert sof, "no JPEG SOF marker"
    height, width = header[sof + 5, 4].unpack("nn")
    assert_equal [ 1200, 630 ], [ width, height ]
  end

  test "every kind of page carries exactly one absolute og:image and twitter:image" do
    series = Series.create!(name: "Share XL")
    season = Season.create!(series: series, number: 1, year: 2021)
    ep     = Episode.create!(season: season, number_in_season: 1, title: "Share Ep", air_date: Date.new(2021, 1, 1), location: locations(:one))
    item   = Item.create!(name: "Share Knife", item_type: "blade")
    [ "/", "/forum", "/items", "/shop", "/series/#{series.id}", "/series", "/seasons", "/episodes", "/locations",
      "/survivors", "/about", "/contact", "/privacy_policy", "/terms_of_service", "/forum/guidelines", "/podcasts",
      "/survivors/#{survivors(:one).to_param}", "/episodes/#{ep.to_param}", "/items/#{item.to_param}",
      "/seasons/#{season.to_param}" ].each { |path| assert_share_image(path) }
  end

  test "a survivor without an avatar falls back to the default share image" do
    url = assert_share_image("/survivors/#{survivors(:one).to_param}")
    assert_match %r{/assets/share-default-}, url
  end

  test "a survivor with an avatar gets a permanent proxy URL, not a signed or expiring one" do
    survivor = Survivor.create!(full_name: "Avatar Person")
    survivor.avatar.attach(io: StringIO.new(PNG), filename: "face.png", content_type: "image/png")

    url = assert_share_image("/survivors/#{survivor.to_param}")
    assert_match %r{\A#{Regexp.escape(ORIGIN)}/rails/active_storage/representations/proxy/}, url
    assert_no_match(/X-Amz|expires|Expires|Signature/, url)
    refute_includes url, "/redirect/"
    assert_equal "600", meta('meta[property="og:image:width"]').first["content"]
    assert_equal "600", meta('meta[property="og:image:height"]').first["content"]
    assert_equal "summary", meta('meta[name="twitter:card"]').first["content"]
    assert_includes meta('meta[property="og:image:alt"]').first["content"], "Avatar Person"
    # Same URL on every request: the signed blob id has no expiry.
    get "/survivors/#{survivor.to_param}"
    assert_equal url, css_select('meta[property="og:image"]').first["content"]
  end

  test "the proxy URL carries no expiry in its signed id" do
    survivor = Survivor.create!(full_name: "Avatar Expiry")
    survivor.avatar.attach(io: StringIO.new(PNG), filename: "face.png", content_type: "image/png")
    url = assert_share_image("/survivors/#{survivor.to_param}")
    signed_id = url[%r{/proxy/([^/]+)/}, 1]
    assert_equal survivor.avatar.blob, ActiveStorage::Blob.find_signed!(signed_id)
    travel 10.years do
      assert_equal survivor.avatar.blob, ActiveStorage::Blob.find_signed!(signed_id)
    end
  end

  test "an episode page uses its first cast avatar through the proxy route, otherwise the default" do
    series = Series.create!(name: "Share Ep XL")
    season = Season.create!(series: series, number: 2, year: 2022)
    ep = Episode.create!(season: season, number_in_season: 1, title: "Cast Ep", air_date: Date.new(2022, 1, 1), location: locations(:one))
    plain = Survivor.create!(full_name: "Plain Cast")
    ep.appearances.create!(survivor: plain)
    assert_match %r{/assets/share-default-}, assert_share_image("/episodes/#{ep.to_param}")

    pretty = Survivor.create!(full_name: "Pretty Cast")
    pretty.avatar.attach(io: StringIO.new(PNG), filename: "face.png", content_type: "image/png")
    ep.appearances.create!(survivor: pretty)
    url = assert_share_image("/episodes/#{ep.to_param}")
    assert_match %r{\A#{Regexp.escape(ORIGIN)}/rails/active_storage/representations/proxy/}, url
  end

  test "structured data images use the permanent canonical-host URL too" do
    survivor = Survivor.create!(full_name: "Ld Avatar")
    survivor.avatar.attach(io: StringIO.new(PNG), filename: "face.png", content_type: "image/png")
    get "/survivors/#{survivor.to_param}"
    person = css_select('script[type="application/ld+json"]').flat_map { |n| Array(JSON.parse(n.text)) }.find { |s| s["@type"] == "Person" }
    assert_match %r{\A#{Regexp.escape(ORIGIN)}/rails/active_storage/blobs/proxy/}, person["image"]
  end

  test "pages never emit a relative or duplicate share image when a view passes one" do
    helper = Object.new.extend(ShareImageHelper)
    assert_equal "#{ORIGIN}/assets/x.jpg", helper.canonical_asset_url("/assets/x.jpg")
    assert_equal "https://cdn.example.com/x.jpg", helper.canonical_asset_url("https://cdn.example.com/x.jpg")
  end
end
