require "test_helper"

# Organization + WebSite JSON-LD: on the home page only, always on the canonical host.
class HomeJsonldTest < ActionDispatch::IntegrationTest
  def json_ld
    css_select('script[type="application/ld+json"]').flat_map { |n| parsed = JSON.parse(n.text); parsed.is_a?(Array) ? parsed : [ parsed ] }
  end

  def node(type) = json_ld.find { |s| s["@type"] == type }

  test "home page emits an Organization with name, canonical url and an absolute logo" do
    get "/"
    assert_response :success
    org = node("Organization")
    assert_equal "https://schema.org", org["@context"]
    assert_equal "Naked & Afraid Fan Wiki", org["name"]
    assert_equal "https://www.nakedandafraidfan.com/", org["url"]
    assert_equal "https://www.nakedandafraidfan.com/#organization", org["@id"]
    logo = org["logo"]
    assert_equal "ImageObject", logo["@type"]
    assert_equal "https://www.nakedandafraidfan.com/favicon.png", logo["url"]
    assert_equal [ 512, 512 ], [ logo["width"], logo["height"] ]
  end

  test "the logo is an existing public asset of the size the markup states" do
    path = Rails.root.join("public", JsonLdHelper::SITE_ORGANIZATION_LOGO_PATH.delete_prefix("/"))
    assert path.exist?, "#{path} must exist"
    width, height = File.binread(path, 24)[16, 8].unpack("N2")
    assert_equal [ JsonLdHelper::SITE_ORGANIZATION_LOGO_SIZE ] * 2, [ width, height ]
  end

  test "home page emits a WebSite that points at the Organization" do
    get "/"
    site = node("WebSite")
    assert_equal "Naked & Afraid Fan Wiki", site["name"]
    assert_equal "https://www.nakedandafraidfan.com/", site["url"]
    assert_equal "https://www.nakedandafraidfan.com/#website", site["@id"]
    assert_equal({ "@id" => "https://www.nakedandafraidfan.com/#organization" }, site["publisher"])
  end

  test "no sameAs and no SearchAction are claimed" do
    get "/"
    assert_not_includes response.body, "sameAs"
    assert_not_includes response.body, "SearchAction"
    assert_not_includes response.body, "potentialAction"
  end

  test "the markup uses the canonical host even when the request host differs" do
    host! "nanda.herokuapp.com"
    get "/"
    assert_response :success
    assert_equal "https://www.nakedandafraidfan.com/", node("Organization")["url"]
    assert_equal "https://www.nakedandafraidfan.com/favicon.png", node("Organization")["logo"]["url"]
    assert_equal "https://www.nakedandafraidfan.com/", node("WebSite")["url"]
  end

  test "the home page keeps its CollectionPage" do
    get "/"
    assert_equal "http://www.example.com/", node("CollectionPage")["url"]
  end

  test "Organization and WebSite appear only on the home page" do
    series = Series.create!(name: "Naked and Afraid")
    season = Season.create!(series: series, number: 1, year: 2020)
    episode = Episode.create!(season: season, number_in_season: 1, title: "Pilot", air_date: Date.new(2020, 1, 1), location: locations(:one), synopsis: "x")
    survivor = Survivor.create!(full_name: "Ann Home")
    Appearance.create!(episode: episode, survivor: survivor)
    paths = %w[/about /contact /privacy_policy /terms_of_service /survivors /episodes /items /food_sources /shelters /locations
               /seasons /series /seasons/latest /shop /shop/guides] +
            [ survivor_path(survivor), episode_path(episode), season_path(season), series_path(series) ]
    paths.each do |path|
      get path
      assert_response :success, path
      assert_empty json_ld.select { |s| %w[Organization WebSite].include?(s["@type"]) }, "#{path} must not emit Organization/WebSite"
      assert_not_includes response.body, "#organization", path
    end
    get "/"
    assert_equal %w[Organization WebSite], json_ld.map { |s| s["@type"] } & %w[Organization WebSite]
  end
end
