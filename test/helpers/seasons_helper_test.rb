require "test_helper"

class SeasonsHelperTest < ActionView::TestCase
  def season_for(series_name, number, series_continuous: false, season_continuous: false)
    series = Series.find_or_create_by!(name: series_name) { |s| s.continuous_story = series_continuous }
    Season.create!(series: series, number: number, year: 2024, continuous_story: season_continuous)
  end

  test "regular series seasons keep the plain label" do
    assert_equal "S5", season_label(season_for("Naked and Afraid", 5))
  end

  test "continuous XL seasons are tagged XL" do
    assert_equal "S5 XL", season_label(season_for("Naked and Afraid XL", 5, series_continuous: true))
  end

  test "XL season 9 is the Frozen run" do
    assert_equal "S9 Frozen", season_label(season_for("Naked and Afraid XL", 9, series_continuous: true))
    assert_equal "S8 XL",     season_label(season_for("Naked and Afraid XL", 8, series_continuous: true))
  end

  test "other continuous series get their short name, long ones abbreviated" do
    assert_equal "S1 Solo",       season_label(season_for("Naked and Afraid: Solo", 1, series_continuous: true))
    assert_equal "S1 Savage",     season_label(season_for("Naked And Afraid Savage", 1, series_continuous: true))
    assert_equal "S1 Castaways",  season_label(season_for("Naked and Afraid Castaways", 1, series_continuous: true))
    assert_equal "S3 LOS",        season_label(season_for("Naked and Afraid Last One Standing", 3, series_continuous: true))
    assert_equal "S1 Apocalypse", season_label(season_for("Naked and Afraid Apocalypse", 1, series_continuous: true))
  end

  test "a season flagged continuous inside a non-continuous series is tagged too" do
    assert_equal "S1 Showdown",    season_label(season_for("Naked and Afraid: Global Showdown", 1, season_continuous: true))
    assert_equal "S1 Shipwrecked", season_label(season_for("Naked and Afraid Shipwrecked", 1, season_continuous: true))
  end

  test "a non-continuous season of a non-continuous series is not tagged" do
    assert_equal "S1", season_label(season_for("Naked and Afraid: Alone", 1))
  end

  test "a flagged flagship series has no tag to add" do
    assert_equal "S2", season_label(season_for("Naked and Afraid", 2, season_continuous: true))
  end

  test "nil season yields an empty label" do
    assert_equal "", season_label(nil)
  end
end
