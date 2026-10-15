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

  test "a location with no episodes reports zero challenges" do
    loc = Location.create!(country: "Iceland", site: "Pin Empty Site", latitude: 64.9, longitude: -18.5)
    assert_equal 0, pins.fetch(loc.id)["challenges_count"]
  end
end
