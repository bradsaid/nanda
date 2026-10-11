require "test_helper"

class SeoUrlsTest < ActionDispatch::IntegrationTest
  def canonical
    css_select("link[rel=canonical]").first["href"]
  end

  def json_ld
    css_select('script[type="application/ld+json"]').flat_map { |n| Array(JSON.parse(n.text)) }
  end

  test "sorting and searching do not change the canonical URL" do
    get survivors_path, params: { sort: "name", q: "test" }
    assert_equal "http://www.example.com/survivors", canonical
    get survivors_path
    assert_equal "http://www.example.com/survivors", canonical
  end

  test "a parameter that selects different content stays in the canonical URL" do
    get episodes_path, params: { location_id: locations(:one).id, sort: "airdate" }
    assert_equal "http://www.example.com/episodes?location_id=#{locations(:one).id}", canonical
  end

  test "og:url matches the canonical URL" do
    get survivors_path, params: { sort: "name" }
    assert_equal canonical, css_select('meta[property="og:url"]').first["content"]
  end

  test "home page structured data uses an absolute image URL" do
    get root_path
    page = json_ld.find { |s| s["@type"] == "CollectionPage" }
    assert_equal "http://www.example.com/favicon.png", page["image"]
    assert_equal "http://www.example.com/", page["url"]
  end

  test "episode structured data credits only survivors still on the episode, with absolute URLs" do
    series = Series.create!(name: "JSON-LD XL", continuous_story: true)
    season = Season.create!(series: series, number: 1, year: 2020)
    stayer = Survivor.create!(full_name: "Json Stayer")
    tapper = Survivor.create!(full_name: "Json Tapper")
    e1 = Episode.create!(season: season, number_in_season: 1, title: "One", air_date: Date.new(2020, 5, 24), location: locations(:one))
    e2 = Episode.create!(season: season, number_in_season: 2, title: "Two", air_date: Date.new(2020, 5, 31), location: locations(:one))
    e1.appearances.create!(survivor: stayer)
    e1.appearances.create!(survivor: tapper, result: "tap_out")
    e2.appearances.create!(survivor: stayer)
    e2.appearances.create!(survivor: tapper)

    get episode_path(e2)
    assert_response :success
    ep = json_ld.find { |s| s["@type"] == "TVEpisode" }
    names = ep["actor"].map { |a| a["name"] }
    assert_equal ["Json Stayer"], names, "a survivor who tapped out earlier must not be credited"
    assert(ep["actor"].all? { |a| a["url"].start_with?("http://www.example.com/survivors/") })
  end
end
