require "test_helper"

# /episodes has four layouts: the season overview (no filter) plus the
# location_id and season_id filtered tables. The "Jump to a season" select only
# makes sense on the overview, and ?country= used to fall into the overview
# layout with an empty @seasons (empty select, zero episodes).
class EpisodesFilteredViewsTest < ActionDispatch::IntegrationTest
  setup do
    @series  = Series.create!(name: "Filter Series")
    @s1      = Season.create!(series: @series, number: 1, year: 2020)
    @s2      = Season.create!(series: @series, number: 2, year: 2021)
    @peru    = Location.create!(country: "Peru", site: "Filter Jungle", latitude: -9.1, longitude: -75.0)
    @chile   = Location.create!(country: "Chile", site: "Filter Desert", latitude: -33.4, longitude: -70.6)
    @ep_peru  = Episode.create!(season: @s1, location: @peru,  title: "Peru Episode",  number_in_season: 1, air_date: Date.new(2020, 1, 1))
    @ep_chile = Episode.create!(season: @s2, location: @chile, title: "Chile Episode", number_in_season: 1, air_date: Date.new(2021, 1, 1))
  end

  def episode_hrefs
    css_select("a[href^='/episodes/']").map { |a| a["href"] }.grep(%r{\A/episodes/\d+\z}).uniq
  end

  test "overview lists every season in the jump dropdown" do
    get episodes_path
    assert_response :success
    values = css_select("select#season-jump option").map { |o| o["value"] }
    assert_includes values, "season-#{@s1.id}"
    assert_includes values, "season-#{@s2.id}"
    assert css_select("#season-#{@s1.id}").any?, "jump target card exists"
  end

  test "country filter redirects permanently to the country page, which lists its episodes" do
    get episodes_path(country: "Peru")
    assert_response :moved_permanently
    assert_redirected_to by_country_episodes_path(country: "Peru")

    follow_redirect!
    assert_response :success
    assert_includes episode_hrefs, episode_path(@ep_peru)
    assert_not_includes episode_hrefs, episode_path(@ep_chile)
    assert_empty css_select("select#season-jump"), "no empty jump select on the country page"
  end

  test "country filter redirect keeps multi-word and mixed-case names" do
    Location.create!(country: "Costa Rica", site: "Filter Coast", latitude: 9.7, longitude: -83.7)
    get episodes_path(country: " costa rica ")
    assert_response :moved_permanently
    assert_redirected_to by_country_episodes_path(country: "costa rica")
    follow_redirect!
    assert_response :success
  end

  test "blank country param falls back to the overview" do
    get episodes_path(country: "  ")
    assert_response :success
    assert css_select("select#season-jump option[value='season-#{@s1.id}']").any?
  end

  test "location filter lists only that location's episodes and has no jump select" do
    get episodes_path(location_id: @peru.id)
    assert_response :success
    assert_includes episode_hrefs, episode_path(@ep_peru)
    assert_not_includes episode_hrefs, episode_path(@ep_chile)
    assert_empty css_select("select#season-jump")
    assert_empty css_select("select#season-sort")
  end

  test "unknown location is a 404" do
    get episodes_path(location_id: 0)
    assert_response :not_found
  end

  test "season filter by id lists only that season's episodes and has no jump select" do
    get episodes_path(season_id: @s2.id)
    assert_response :success
    assert_includes episode_hrefs, episode_path(@ep_chile)
    assert_not_includes episode_hrefs, episode_path(@ep_peru)
    assert_empty css_select("select#season-jump")
  end

  test "season filter by series and number works" do
    get episodes_path(series_id: @series.id, season: @s1.number)
    assert_response :success
    assert_includes episode_hrefs, episode_path(@ep_peru)
    assert_not_includes episode_hrefs, episode_path(@ep_chile)
  end

  test "unknown season is a 404" do
    get episodes_path(season_id: 0)
    assert_response :not_found
  end
end
