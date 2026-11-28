require "test_helper"

# Representative long titles for every page type: each stays within the single title cap
# (SeoHelper::MAX_TITLE_LENGTH), falls back deterministically, and keeps the key entity.
class PageTitlesHelperTest < ActionView::TestCase
  include SeoHelper
  include SeasonsHelper
  include FranchiseHelper
  include RegionsHelper

  LIMIT = SeoHelper::MAX_TITLE_LENGTH
  LONG  = "Extraordinarily Long Name Of Something That Goes On And On Forever And Ever".freeze

  def assert_fits(title, msg = nil)
    assert_operator title.length, :<=, LIMIT, "#{msg}: #{title.inspect} is #{title.length} characters"
  end

  test "the cap is 60, defined once" do
    assert_equal 60, SeoHelper::MAX_TITLE_LENGTH
  end

  # ---------- SeoHelper ----------

  test "site_title takes the first candidate that fits, then adds the site name only if it still fits" do
    assert_equal "Short — Naked & Afraid Fan Wiki", site_title("Short")
    assert_equal "B" * 40, site_title("A" * 70, "B" * 40)
    assert_equal "A" * 50, site_title("A" * 50)
    assert_equal "Naked & Afraid Fan Wiki", site_title("", nil)
  end

  test "site_title cuts the last candidate at a word boundary only as a last resort" do
    t = site_title("lorem ipsum " * 20)
    assert_fits t
    assert t.end_with?("…")
    assert_includes %w[lorem ipsum], t.delete_suffix("…").split.last
  end

  test "site_title and paginated_title leave room for the page suffix" do
    assert_equal "Survivors — Page 3", paginated_title("Survivors", 3)
    assert_equal "Survivors", paginated_title("Survivors", 1)
    long = "word " * 30
    t = paginated_title(long, 12)
    assert_fits t
    assert t.end_with?("… — Page 12"), t
    t = site_title("A " * 29, "A" * 56, page: 2)
    assert_fits t
    assert t.end_with?(" — Page 2"), t
  end

  test "fitted_title never adds the site name" do
    assert_equal "Survivors", fitted_title("Survivors")
    assert_equal "Fits", fitted_title("x" * 80, "Fits")
    assert_equal "Fits — Page 4", fitted_title("x" * 80, "Fits", page: 4)
  end

  # ---------- PageTitlesHelper ----------

  test "survivor titles keep the name and drop the qualifiers first" do
    assert_equal "Ann Alpha – Naked and Afraid Survivor", survivor_page_title("Ann Alpha")
    long = "Maximilian Bartholomew Featherstonehaugh-Montgomery III"
    assert_equal long, survivor_page_title(long)
    assert_fits survivor_page_title(LONG)
  end

  test "item titles, with and without a country filter" do
    assert_equal "pot – Naked and Afraid Item", item_page_title("pot")
    assert_equal "pot – Naked and Afraid Item — in Panama", item_page_title("pot", country: "Panama")
    t = item_page_title("collapsible titanium cooking pot", country: "Saint Vincent and the Grenadines")
    assert_fits t
    # the item name is the key entity: when the country cannot fit it is dropped, never the item
    assert_includes t, "collapsible titanium cooking pot"
    assert_fits item_page_title(LONG)
    assert_fits item_page_title(LONG, country: LONG)
    assert_includes item_page_title("Machete", country: "Saint Vincent and the Grenadines"), "Machete"
  end

  test "item type, country, food source and shelter titles" do
    assert_equal "Knife Items – Naked and Afraid", item_type_page_title("Knife")
    assert_fits item_type_page_title(LONG, country: LONG)
    assert_includes item_type_page_title("Pot", country: "Saint Vincent and the Grenadines"), "Pot Items"

    assert_equal "Naked and Afraid Episodes in Panama", country_episodes_title("Panama")
    assert_equal "Naked and Afraid in Saint Vincent and the Grenadines", country_episodes_title("Saint Vincent and the Grenadines")
    assert_equal "Naked and Afraid Episodes in Panama — Page 2", country_episodes_title("Panama", page: 2)
    assert_fits country_episodes_title("Saint Vincent and the Grenadines", page: 12)
    assert_fits country_episodes_title(LONG, page: 12)

    assert_equal "Frog – Naked and Afraid Food Source", food_source_page_title("Frog")
    assert_includes food_source_page_title(LONG), LONG.split.first
    assert_fits food_source_page_title(LONG)
    assert_equal "Lean-to – Naked and Afraid Shelter", shelter_page_title("Lean-to")
    assert_fits shelter_page_title(LONG)
  end

  test "episode-index titles for a location and a season" do
    loc = Location.new(country: "Saint Vincent and the Grenadines", region: "Windward Islands Archipelago", site: "Northern Mountain Rainforest Reserve")
    assert_fits location_episodes_title(loc)
    assert_equal "Naked and Afraid Episodes in Panama", location_episodes_title(Location.new(country: "Panama"))
    assert_equal "Naked and Afraid Episodes in Unknown Location", location_episodes_title(Location.new)

    assert_equal "Naked and Afraid – Season 4 (Episode Guide)", season_episodes_title("Naked and Afraid", 4)
    t = season_episodes_title("Naked and Afraid: Castaways of the Pacific Ocean Expedition", 11)
    assert_fits t
    assert_includes t, "Season 11"
  end

  test "forum topic titles cut a long topic at a word boundary" do
    assert_equal "Best knife — Forum", forum_topic_title("Best knife")
    t = forum_topic_title("What is the very best survival knife for a twenty-one day challenge in the jungle?", page: 3)
    assert_fits t
    assert t.end_with?(" — Page 3"), t
  end

  # ---------- franchise and region titles ----------

  def episode(series_name, season_number, number, title)
    Episode.new(title: title, number_in_season: number, season: Season.new(number: season_number, series: Series.new(name: series_name)))
  end

  test "episode titles keep Season N Episode M when it fits and fall back deterministically" do
    assert_equal "Naked and Afraid Season 14 Episode 2: Haunted", episode_page_title(episode("Naked and Afraid", 14, 2, "Haunted")).delete_suffix(" — Naked & Afraid Fan Wiki")
    # 61 chars in full: the compact code keeps the whole title
    assert_equal "Naked and Afraid Shipwrecked S1E1: Abandon Ship", episode_page_title(episode("Naked and Afraid: Shipwrecked", 1, 1, "Abandon Ship"))
    # a long title is cut at a word, series + season + episode are kept
    t = episode_page_title(episode("Naked and Afraid", 14, 12, LONG))
    assert_fits t
    assert t.start_with?("Naked and Afraid Season 14 Episode 12: Extraordinarily"), t
    assert t.end_with?("…")
    # a very long series name drops its "Naked and Afraid" prefix but keeps the code
    t = episode_page_title(episode("Naked and Afraid: Castaways of the Pacific Ocean Expedition", 11, 14, "Escape"))
    assert_fits t
    assert_includes t, "S11E14"
    assert_includes t, "Castaways of the Pacific Ocean Expedition"
    # no title: just the phrase
    assert_equal "Naked and Afraid Season 2 Episode 3", episode_page_title(episode("Naked and Afraid", 2, 3, nil)).delete_suffix(" — Naked & Afraid Fan Wiki")
    # always bounded, whatever the names
    [ "x" * 100, "Naked and Afraid " + "y" * 100 ].each do |series|
      assert_fits episode_page_title(episode(series, 99, 99, LONG)), series
    end
  end

  test "season, series and region titles fit for long names" do
    [ "Naked and Afraid", "Naked and Afraid: Castaways of the Pacific Ocean Expedition", "z" * 90 ].each do |name|
      assert_fits season_page_title(Season.new(number: 12, series: Series.new(name: name))), name
      assert_fits series_page_title(Series.new(name: name)), name
    end
    assert_includes season_page_title(Season.new(number: 11, series: Series.new(name: "Naked and Afraid: Castaways of the Pacific Ocean Expedition"))), "Season 11"
    assert_fits seasons_index_title
    assert_fits series_index_title
    assert_fits region_title(Struct.new(:name).new("Central America & Caribbean"))
    assert_fits region_title(Struct.new(:name).new(LONG))
    assert_includes region_title(Struct.new(:name).new("Central America & Caribbean")), "Central America & Caribbean"
  end
end
