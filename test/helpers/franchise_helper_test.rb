require "test_helper"

class FranchiseHelperTest < ActionView::TestCase
  include SeoHelper
  include SeasonsHelper

  test "display_series_name drops the colon after Naked and Afraid" do
    assert_equal "Naked and Afraid Solo", display_series_name("Naked and Afraid: Solo")
    assert_equal "Naked and Afraid XL", display_series_name("Naked and Afraid XL")
    assert_equal "Naked and Afraid", display_series_name("Naked and Afraid")
    assert_equal "Naked and Afraid", display_series_name(nil)
    assert_equal "Naked And Afraid Savage", display_series_name("Naked And Afraid Savage")
  end

  test "season_full_name always carries the series" do
    xl = Season.new(number: 10, series: Series.new(name: "Naked and Afraid XL"))
    regular = Season.new(number: 10, series: Series.new(name: "Naked and Afraid"))
    assert_equal "Naked and Afraid XL Season 10", season_full_name(xl)
    assert_equal "Naked and Afraid Season 10", season_full_name(regular)
  end

  test "fit_title picks the first candidate that fits, else the last" do
    assert_equal "short", fit_title("short", "x")
    assert_equal "b" * 10, fit_title("a" * 100, "b" * 10, "c")
    assert_equal "c" * 90, fit_title("a" * 100, "c" * 90)
  end

  test "short_list names a few and counts the rest" do
    assert_equal "A, B, and C", short_list(%w[A B C], max: 3)
    assert_equal "A, B, C and 2 more", short_list(%w[A B C D E], max: 3)
    assert_equal "A", short_list(%w[A])
  end

  test "season titles stay within the budget for every series name length" do
    [ "Naked and Afraid", "Naked and Afraid XL", "Naked and Afraid: Solo", "Naked and Afraid Last One Standing", "Naked and Afraid: Global Showdown" ].each do |name|
      season = Season.new(number: 12, series: Series.new(name: name))
      t = season_page_title(season)
      assert_operator t.length, :<=, SeoHelper::MAX_TITLE_LENGTH, t
      assert t.start_with?(season_full_name(season)), t
    end
    assert_equal "Naked and Afraid Last One Standing Season 12: Cast & Episodes", season_page_title(Season.new(number: 12, series: Series.new(name: "Naked and Afraid Last One Standing")))
  end
end
