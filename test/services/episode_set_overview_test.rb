require "test_helper"

class EpisodeSetOverviewTest < ActiveSupport::TestCase
  setup do
    @loc_a = Location.create!(country: "Peru", region: "R", site: "Site A", latitude: -9.2, longitude: -75.0)
    @loc_b = Location.create!(country: "Fiji", region: "R", site: "Site B", latitude: -17.7, longitude: 178.0)
    series = Series.create!(name: "Overview Series")
    @season = Season.create!(series: series, number: 1, year: 2020)
    @e1 = Episode.create!(season: @season, number_in_season: 1, title: "One", air_date: Date.new(2020, 12, 30), location: @loc_a, scheduled_days: 21, participant_arrangement: "2+2")
    @e2 = Episode.create!(season: @season, number_in_season: 2, title: "Two", air_date: Date.new(2021, 1, 6), location: @loc_b, scheduled_days: 40)
    @e3 = Episode.create!(season: @season, number_in_season: 3, title: "Three", location: @loc_a)
    @ann = Survivor.create!(full_name: "Ann One")
    @bob = Survivor.create!(full_name: "Bob Two")
    @a1 = Appearance.create!(episode: @e1, survivor: @ann)
    @a2 = Appearance.create!(episode: @e1, survivor: @bob)
    @a3 = Appearance.create!(episode: @e2, survivor: @ann)
  end

  def overview
    eps = @season.episodes.includes(:location, appearances: :survivor).order(:number_in_season).to_a
    EpisodeSetOverview.new(eps)
  end

  test "dates, years, countries and days come from the episodes that have them" do
    ov = overview
    assert_equal 3, ov.episode_count
    assert_equal Date.new(2020, 12, 30), ov.premiere
    assert_equal Date.new(2021, 1, 6), ov.finale
    assert_equal "2020–2021", ov.years_label
    assert_equal %w[Peru Fiji], ov.countries
    assert_equal [ 21, 40 ], ov.scheduled_days
    assert_equal [ [ "Site A, R, Peru", 2 ], [ "Site B, R, Fiji", 1 ] ], ov.location_counts.map { |l, n, _| [ l, n ] }
  end

  test "nothing recorded gives nil/empty, never zero" do
    ov = overview
    assert_nil ov.results
    assert_nil ov.top_psr
    assert_empty ov.weight_loss_rows
    assert_not ov.weight_loss_recorded?
    assert_empty ov.brought_items
    empty = EpisodeSetOverview.new([])
    assert_nil empty.premiere
    assert_nil empty.years_label
    assert_empty empty.survivors
  end

  test "a survivor counts once, by their latest recorded result" do
    @a1.update!(result: "tap_out")
    @a3.update!(result: "success") # Ann appears in two episodes
    @a2.update!(result: "medical_tap_out")
    r = overview.results
    assert_equal 2, r.recorded
    assert_equal 2, r.survivor_total
    assert_equal [ @ann ], r.completed
    assert_equal [ @bob ], r.tapped_out
    assert_equal [ @bob ], r.medical
    assert_empty r.eliminated
  end

  test "top PSR, weight loss ordering and PSR formatting" do
    @a1.update!(ending_psr: 6.5, weight_loss: 10)
    @a2.update!(ending_psr: 6.5, weight_loss: 15)
    @a3.update!(ending_psr: 8, weight_loss: 0)
    ov = overview
    assert_equal 8, ov.top_psr[:value]
    assert_equal [ @ann ], ov.top_psr[:survivors]
    assert_equal [ 15, 10, 0 ], ov.weight_loss_rows.map { |r| r[:value].to_i }
    assert_equal "8", EpisodeSetOverview.format_psr(8)
    assert_equal "6.5", EpisodeSetOverview.format_psr(BigDecimal("6.50"))
    assert_nil EpisodeSetOverview.format_psr(nil)
  end

  test "team count is only reported when the arrangement names several teams" do
    assert_equal 2, overview.team_count
    assert_equal "2+2", overview.team_arrangement
    @e1.update!(participant_arrangement: "Group")
    assert_nil overview.team_count
  end

  test "brought items need at least two takers to be listed" do
    knife = Item.create!(name: "Overview Knife", item_type: "blade")
    rope  = Item.create!(name: "Overview Rope", item_type: "tool")
    AppearanceItem.create!(appearance: @a1, item: knife, source: "brought")
    AppearanceItem.create!(appearance: @a2, item: rope, source: "brought")
    assert_empty overview.brought_items
    AppearanceItem.create!(appearance: @a2, item: knife, source: "brought")
    AppearanceItem.create!(appearance: @a3, item: knife, source: "given") # not "brought": ignored
    assert_equal [ [ knife, 2 ], [ rope, 1 ] ], overview.brought_items
  end
end
