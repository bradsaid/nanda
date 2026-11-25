require "test_helper"

# JSON-LD must say what the page says: survivor numbers, ItemList sizes, forum threads.
class StructuredDataAccuracyTest < ActionDispatch::IntegrationTest
  def json_ld
    css_select('script[type="application/ld+json"]').flat_map { |n| parsed = JSON.parse(n.text); parsed.is_a?(Array) ? parsed : [ parsed ] }
  end

  def schema(type) = json_ld.find { |s| s["@type"] == type }

  # ---------- survivor description ----------

  test "survivor Person description uses the episode and challenge numbers the page shows" do
    series = Series.create!(name: "Accuracy XL", continuous_story: true)
    season = Season.create!(series: series, number: 1, year: 2021)
    survivor = Survivor.create!(full_name: "Matt Accurate")
    5.times do |i|
      ep = Episode.create!(season: season, number_in_season: i + 1, title: "Acc #{i}", air_date: Date.new(2021, 1, 1) + i, location: locations(:one))
      ep.appearances.create!(survivor: survivor)
    end

    get survivor_path(survivor)
    assert_response :success
    # What the page shows: 5 episodes, 1 challenge (a continuous season counts once).
    assert_select ".stat-pill", text: /Challenges:\s*1\b/
    assert_select ".stat-pill", text: /Episodes:\s*5\b/
    person = schema("Person")
    assert_equal "Matt Accurate from Naked and Afraid appeared in 5 episodes across 1 challenge.", person["description"]
    assert_equal "Matt Accurate appeared in 5 episodes across 1 challenge.", css_select('meta[property="og:description"]').first["content"]
  end

  test "survivor wording is correct when episodes and challenges match, and when there are none" do
    helper = Object.new.extend(SurvivorsHelper)
    helper.extend(ActionView::Helpers::TextHelper)
    assert_equal "appeared in 78 episodes across 12 challenges", helper.survivor_appearance_summary(78, 12)
    assert_equal "appeared in 1 episode across 1 challenge", helper.survivor_appearance_summary(1, 1)
    assert_equal "has no episodes on record yet", helper.survivor_appearance_summary(0, 0)

    get survivor_path(Survivor.create!(full_name: "Nobody Yet"))
    assert_equal "Nobody Yet from Naked and Afraid has no episodes on record yet.", schema("Person")["description"]
  end

  # ---------- ItemList sizes ----------

  def assert_item_list_consistent(list, first_position: 1)
    items = list["itemListElement"]
    assert_equal items.size, list["numberOfItems"], "numberOfItems must equal the entries emitted"
    assert_equal (first_position...(first_position + items.size)).to_a, items.map { |i| i["position"] }
  end

  test "/survivors ItemList lists the page's survivors and numberOfItems equals them" do
    (1..10).each { |i| Survivor.create!(full_name: format("List %02d Person", i)) }
    get survivors_path
    list = schema("ItemList")
    assert_item_list_consistent(list)
    assert_equal Survivor.count, list["numberOfItems"] # fewer than a page: all of them, not just 6
    assert_operator list["numberOfItems"], :>, 6
  end

  test "/survivors page 2 positions continue from the page offset" do
    (1..(SurvivorsController::PER_PAGE + 5)).each { |i| Survivor.create!(full_name: format("Offset %03d Person", i)) }
    get survivors_path(page: 2)
    assert_response :success
    list = schema("ItemList")
    assert_item_list_consistent(list, first_position: SurvivorsController::PER_PAGE + 1)
    assert_equal Survivor.count - SurvivorsController::PER_PAGE, list["numberOfItems"]
  end

  test "/episodes ItemList numberOfItems equals the entries emitted" do
    series = Series.create!(name: "Counted XL")
    5.times do |n|
      season = Season.create!(series: series, number: n + 1, year: 2010 + n)
      6.times { |i| Episode.create!(season: season, number_in_season: i + 1, title: "Count #{n}-#{i}", air_date: Date.new(2010 + n, 1, i + 1), location: locations(:one)) }
    end
    get episodes_path
    assert_response :success
    list = json_ld.find { |s| s["@type"] == "ItemList" }
    assert_item_list_consistent(list)
    assert_operator Episode.count, :>, list["numberOfItems"]
  end

  test "/episodes/by_country ItemList is the current page's episodes" do
    loc = Location.create!(country: "Accuracyland", region: "North", site: "Camp", latitude: 1.5, longitude: 2.5)
    series = Series.create!(name: "Country XL")
    (1..(EpisodesController::COUNTRY_BLOCKS_PER_PAGE + 3)).each do |n|
      season = Season.create!(series: series, number: n, year: 2000 + n)
      Episode.create!(season: season, number_in_season: 1, title: "Country #{n}", air_date: Date.new(2000 + n, 1, 1), location: loc)
    end
    get "/episodes/by_country/accuracyland"
    assert_response :success
    list = json_ld.find { |s| s["@type"] == "ItemList" }
    assert_item_list_consistent(list)
    assert_equal EpisodesController::COUNTRY_BLOCKS_PER_PAGE, list["numberOfItems"]

    get "/episodes/by_country/accuracyland", params: { page: 2 }
    list = json_ld.find { |s| s["@type"] == "ItemList" }
    assert_item_list_consistent(list, first_position: EpisodesController::COUNTRY_BLOCKS_PER_PAGE + 1)
    assert_equal 3, list["numberOfItems"]
  end
end
