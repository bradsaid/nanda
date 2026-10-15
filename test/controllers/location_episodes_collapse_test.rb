require "test_helper"

class LocationEpisodesCollapseTest < ActionDispatch::IntegrationTest
  setup do
    @loc   = Location.create!(country: "Peru", site: "Collapse Site", latitude: -9.1, longitude: -75.0)
    @other = Location.create!(country: "Chile", site: "Elsewhere", latitude: -33.4, longitude: -70.6)
  end

  def add_episodes(season, location, titles, start_date: Date.new(2024, 1, 1))
    titles.each_with_index do |title, i|
      Episode.create!(season: season, location: location, title: title,
                      number_in_season: season.episodes.maximum(:number_in_season).to_i + 1,
                      air_date: start_date + (i * 7))
    end
  end

  def rows
    css_select("table tbody tr")
  end

  test "a continuous season with several episodes here is one collapsed row" do
    cont = Season.create!(series: Series.create!(name: "Collapse Cont"), number: 3, year: 2024, continuous_story: true)
    add_episodes(cont, @loc, ["Part One", "Part Two", "Part Three"])

    get episodes_path(location_id: @loc.id)
    assert_response :success

    assert_equal 1, rows.size, "three episodes should collapse into one row"
    row = rows.first
    assert_equal 1, row.css("details").size
    assert_includes row.css("summary").text, "Collapse Cont Season 3: 3 episodes"
    assert_includes row.css("summary").text, "Continuous Story"
    links = row.css("details ul li a").map { |a| a.text.strip }
    assert_equal ["Part One #1", "Part Two #2", "Part Three #3"], links, "episodes listed in air order"
    assert_includes row.text, "Jan 1, 2024 – Jan 15, 2024"
  end

  test "details start collapsed" do
    cont = Season.create!(series: Series.create!(name: "Collapse Closed"), number: 1, year: 2024, continuous_story: true)
    add_episodes(cont, @loc, ["A", "B"])
    get episodes_path(location_id: @loc.id)
    assert_nil css_select("details").first["open"]
  end

  test "normal seasons still list one row per episode" do
    normal = Season.create!(series: Series.create!(name: "Collapse Normal"), number: 1, year: 2024)
    add_episodes(normal, @loc, ["N1", "N2", "N3"])
    get episodes_path(location_id: @loc.id)
    assert_equal 3, rows.size
    assert_empty css_select("details")
  end

  test "a continuous season with a single episode here is not collapsed" do
    cont = Season.create!(series: Series.create!(name: "Collapse Single"), number: 1, year: 2024, continuous_story: true)
    add_episodes(cont, @loc, ["Only Here"])
    add_episodes(cont, @other, ["Over There 1", "Over There 2"])

    get episodes_path(location_id: @loc.id)
    assert_equal 1, rows.size
    assert_empty css_select("details")
    assert_includes rows.first.text, "Only Here"
  end

  test "a series flagged continuous collapses each of its seasons separately" do
    series = Series.create!(name: "Collapse Series", continuous_story: true)
    s1 = Season.create!(series: series, number: 1, year: 2023)
    s2 = Season.create!(series: series, number: 2, year: 2024)
    add_episodes(s1, @loc, ["S1A", "S1B"], start_date: Date.new(2023, 1, 1))
    add_episodes(s2, @loc, ["S2A", "S2B", "S2C"], start_date: Date.new(2024, 1, 1))

    get episodes_path(location_id: @loc.id)
    assert_equal 2, rows.size
    summaries = css_select("summary").map { |s| s.text.gsub(/\s+/, " ").strip }
    assert(summaries.any? { |t| t.include?("Season 2: 3 episodes") })
    assert(summaries.any? { |t| t.include?("Season 1: 2 episodes") })
  end

  test "collapsed and normal rows mix, newest first" do
    old_normal = Season.create!(series: Series.create!(name: "Collapse Old"), number: 1, year: 2020)
    cont = Season.create!(series: Series.create!(name: "Collapse New"), number: 1, year: 2024, continuous_story: true)
    add_episodes(old_normal, @loc, ["Old Episode"], start_date: Date.new(2020, 1, 1))
    add_episodes(cont, @loc, ["New A", "New B"], start_date: Date.new(2024, 1, 1))

    get episodes_path(location_id: @loc.id)
    assert_equal 2, rows.size
    assert_includes rows.first.text, "Collapse New Season 1"
    assert_includes rows.last.text, "Old Episode"
  end

  test "the collapsed row shows the combined cast once" do
    cont = Season.create!(series: Series.create!(name: "Collapse Cast"), number: 1, year: 2024, continuous_story: true)
    add_episodes(cont, @loc, ["C1", "C2"])
    survivor = Survivor.create!(full_name: "Collapse Cast Member")
    cont.episodes.each { |e| Appearance.create!(survivor: survivor, episode: e) }

    get episodes_path(location_id: @loc.id)
    assert_equal 1, rows.first.css("a[href*='survivors']").size
    assert_includes rows.first.text, "Collapse Cast Member"
  end
end
