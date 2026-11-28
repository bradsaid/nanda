require "test_helper"

# The home page's "Top Countries" card is headed "Challenges" and shows each country's
# challenge count, so it must be ordered by that number (highest first, ties alphabetical),
# not by raw episode count.
class HomeTopCountriesTest < ActionDispatch::IntegrationTest
  def location_in(country, site = "#{country} site")
    # Coordinates are supplied so the model never calls the geocoding API.
    Location.create!(country: country, site: site, latitude: 1.0, longitude: 1.0)
  end

  def add_episodes(season, location, count)
    count.times do |i|
      Episode.create!(season: season, location: location, title: "#{location.country} ep #{season.number}-#{i}-#{SecureRandom.hex(2)}",
                      number_in_season: season.episodes.count + 1, air_date: Date.new(2024, 1, 1) + i)
    end
  end

  def listed_countries
    get "/"
    assert_response :success
    css_select("table.top-countries-table tr").map do |tr|
      name, count = tr.css("td").map { |td| td.text.strip }
      [ name, count.delete(",").to_i ]
    end
  end

  test "ranks by the challenge number shown, not by episode count" do
    standard   = Season.create!(series: series(:one), number: 11, year: 2020, continuous_story: false)
    continuous = Season.create!(series: series(:one), number: 12, year: 2021, continuous_story: true)

    # Standard season: 3 episodes in Mexico = 3 challenges.
    add_episodes(standard, location_in("Mexico"), 3)
    # Continuous-story season: 8 episodes in ONE place = 1 challenge. By episode count the
    # Philippines (8) beat Mexico (3); by the challenges column Mexico (3) beats it (1).
    add_episodes(continuous, location_in("Philippines"), 8)

    rows = listed_countries.select { |name, _| %w[Mexico Philippines].include?(name) }
    assert_equal [ [ "Mexico", 3 ], [ "Philippines", 1 ] ], rows
  end

  test "the displayed numbers are never ascending down the list" do
    standard = Season.create!(series: series(:one), number: 13, year: 2022, continuous_story: false)
    { "Peru" => 4, "Fiji" => 2, "Brazil" => 5, "Namibia" => 3 }.each { |country, n| add_episodes(standard, location_in(country), n) }

    counts = listed_countries.map(&:last)
    assert_equal counts.sort.reverse, counts
    assert_equal "Brazil", listed_countries.first.first
  end

  test "countries with the same challenge count are listed alphabetically" do
    standard = Season.create!(series: series(:one), number: 14, year: 2023, continuous_story: false)
    %w[Zambia Argentina Morocco].each { |country| add_episodes(standard, location_in(country), 6) }

    names = listed_countries.map(&:first)
    assert_equal %w[Argentina Morocco Zambia], names.first(3)
  end

  test "only the top five countries are listed" do
    standard = Season.create!(series: series(:one), number: 15, year: 2023, continuous_story: false)
    %w[A B C D E F G].each_with_index { |c, i| add_episodes(standard, location_in("Country #{c}"), 10 + i) }

    names = listed_countries.map(&:first)
    assert_equal 5, names.size
    assert_equal [ "Country G", "Country F", "Country E", "Country D", "Country C" ], names
  end

  test "rank_countries orders by count descending then name, drops blanks and limits" do
    ranked = HomeController.rank_countries(
      { "Philippines" => 12, "Mexico" => 18, "brazil" => 12, "" => 99, nil => 50, "Chile" => 1 }, limit: 4)
    assert_equal [ "Mexico", "brazil", "Philippines", "Chile" ], ranked.keys
    assert_equal [ 18, 12, 12, 1 ], ranked.values
  end
end
