require "test_helper"

class LocationsMapTest < ActionDispatch::IntegrationTest
  def pins
    get locations_path(format: :json)
    assert_response :success
    JSON.parse(response.body).index_by { |p| p["id"] }
  end

  def add_episodes(season, location, count)
    count.times do |i|
      Episode.create!(season: season, location: location,
                      number_in_season: season.episodes.maximum(:number_in_season).to_i + 1,
                      title: "Pin test #{season.id}-#{i}")
    end
  end

  test "pins count each episode of a normal season as its own challenge" do
    series = Series.create!(name: "Pin Normal")
    season = Season.create!(series: series, number: 1, year: 2020)
    loc = Location.create!(country: "Peru", site: "Pin Normal Site", latitude: -9.1, longitude: -75.0)
    add_episodes(season, loc, 3)

    pin = pins.fetch(loc.id)
    assert_equal 3, pin["challenges_count"]
  end

  test "pins count a continuous-story season as a single challenge" do
    series = Series.create!(name: "Pin Continuous")
    season = Season.create!(series: series, number: 1, year: 2021, continuous_story: true)
    loc = Location.create!(country: "Chile", site: "Pin Continuous Site", latitude: -33.4, longitude: -70.6)
    add_episodes(season, loc, 5)

    pin = pins.fetch(loc.id)
    assert_equal 1, pin["challenges_count"]
    assert_equal 5, pin["episodes_count"], "raw episode count is still reported"
  end

  test "a series flagged continuous makes all its seasons one challenge each" do
    series = Series.create!(name: "Pin Series Continuous", continuous_story: true)
    s1 = Season.create!(series: series, number: 1, year: 2022)
    s2 = Season.create!(series: series, number: 2, year: 2023)
    loc = Location.create!(country: "Fiji", site: "Pin Series Site", latitude: -17.7, longitude: 178.0)
    add_episodes(s1, loc, 4)
    add_episodes(s2, loc, 4)

    assert_equal 2, pins.fetch(loc.id)["challenges_count"]
  end

  test "normal and continuous seasons at one pin add up" do
    normal = Season.create!(series: Series.create!(name: "Pin Mixed N"), number: 1, year: 2020)
    cont = Season.create!(series: Series.create!(name: "Pin Mixed C"), number: 1, year: 2021, continuous_story: true)
    loc = Location.create!(country: "Panama", site: "Pin Mixed Site", latitude: 8.5, longitude: -80.0)
    add_episodes(normal, loc, 2)
    add_episodes(cont, loc, 6)

    assert_equal 3, pins.fetch(loc.id)["challenges_count"]
  end

  # Two countries that sort differently depending on the metric:
  #   Zzland: 2 standard episodes  -> 2 challenges, 2 episodes
  #   Yyland: 1 continuous season of 5 episodes -> 1 challenge, 5 episodes
  def build_sort_fixture
    zz = Location.create!(country: "Zzland", site: "Sort Z", latitude: 1.0, longitude: 1.0)
    yy = Location.create!(country: "Yyland", site: "Sort Y", latitude: 2.0, longitude: 2.0)
    add_episodes(Season.create!(series: Series.create!(name: "Sort Normal"), number: 1, year: 2020), zz, 2)
    add_episodes(Season.create!(series: Series.create!(name: "Sort Cont"), number: 1, year: 2021, continuous_story: true), yy, 5)
  end

  def country_order
    css_select("#countries-results .country-card .fw-semibold").map { |n| n.text.strip }
  end

  test "countries sort by challenges by default and by challenges explicitly" do
    build_sort_fixture
    [{}, { sort: "challenges" }].each do |params|
      get locations_path, params: params
      order = country_order
      assert_operator order.index("Zzland"), :<, order.index("Yyland"), "2 challenges should outrank 1 (#{params})"
    end
  end

  test "countries sort by episodes" do
    build_sort_fixture
    get locations_path, params: { sort: "episodes" }
    order = country_order
    assert_operator order.index("Yyland"), :<, order.index("Zzland"), "5 episodes should outrank 2"
  end

  test "countries sort A to Z" do
    build_sort_fixture
    get locations_path, params: { sort: "name" }
    order = country_order
    assert_equal order.sort_by(&:downcase), order
  end

  test "unknown sort values fall back to challenges" do
    build_sort_fixture
    get locations_path, params: { sort: "bogus" }
    order = country_order
    assert_operator order.index("Zzland"), :<, order.index("Yyland")
  end

  test "country cards show challenge and episode counts" do
    build_sort_fixture
    get locations_path
    card = css_select("#countries-results .country-card").find { |c| c.text.include?("Yyland") }
    assert_includes card.text, "1 challenge"
    assert_includes card.text, "5 episodes"
  end

  test "sort pills include Episodes" do
    get locations_path
    labels = css_select('[aria-label="Sort countries"] a').map { |a| a.text.strip }
    assert_equal ["Challenges", "Episodes", "A–Z"], labels
  end

  test "a location with no episodes reports zero challenges" do
    loc = Location.create!(country: "Iceland", site: "Pin Empty Site", latitude: 64.9, longitude: -18.5)
    assert_equal 0, pins.fetch(loc.id)["challenges_count"]
  end
end
