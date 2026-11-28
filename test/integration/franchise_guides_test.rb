require "test_helper"

# /seasons and /series are franchise guides: quick answers, a series-in-order timeline and a
# short FAQ, all computed from the data (FranchiseStats) with correct pluralization.
class FranchiseGuidesTest < ActionDispatch::IntegrationTest
  def title = css_select("head title").first.text
  def description = css_select('head meta[name="description"]').first["content"]
  def json_ld = css_select('script[type="application/ld+json"]').flat_map { |n| p = JSON.parse(n.text); p.is_a?(Array) ? p : [ p ] }
  def faq = json_ld.find { |s| s["@type"] == "FAQPage" }
  def answers = faq["mainEntity"].to_h { |q| [ q["name"], CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(q["acceptedAnswer"]["text"])).squish ] }

  setup do
    Rails.cache.clear
    @loc1 = Location.create!(country: "Fiji", region: "R", site: "S", latitude: -17.7, longitude: 178.0)
    @loc2 = Location.create!(country: "Peru", region: "R", site: "S", latitude: -9.2, longitude: -75.0)
    @flagship = Series.create!(name: "Naked and Afraid")
    @spin     = Series.create!(name: "Naked and Afraid: Guide Spin")
    @late     = Series.create!(name: "Naked and Afraid Guide Late")
    fs = Season.create!(series: @flagship, number: 1, year: 1990)
    fs2 = Season.create!(series: @flagship, number: 2, year: 1991)
    ss = Season.create!(series: @spin, number: 1, year: 1995)
    ls = Season.create!(series: @late, number: 1, year: 1999)
    @first  = Episode.create!(season: fs, number_in_season: 1, title: "The Very First", air_date: Date.new(1990, 6, 1), location: @loc1)
    Episode.create!(season: fs, number_in_season: 2, title: "Second", air_date: Date.new(1990, 6, 8), location: @loc1)
    Episode.create!(season: fs2, number_in_season: 1, title: "Season Two", air_date: Date.new(1991, 6, 1), location: @loc2)
    Episode.create!(season: ss, number_in_season: 1, title: "Spin One", air_date: Date.new(1995, 1, 1), location: @loc2)
    @last = Episode.create!(season: ls, number_in_season: 1, title: "The Latest", air_date: Date.new(1999, 1, 1), location: @loc2)
  end

  test "/seasons title, description and quick answers use the data" do
    get seasons_path
    assert_response :success
    # The old wording was 61 characters, over the 60-character cap (was 65): the next candidate wins.
    assert_equal "All Naked and Afraid Seasons: Episodes & Cast", title
    assert_operator title.length, :<=, SeoHelper::MAX_TITLE_LENGTH
    assert_operator description.length, :<=, 160
    assert_includes description, "#{Season.count} Naked and Afraid seasons across #{Series.count} series (#{Episode.count} episodes)"

    glance = css_select("#quick-answers-heading").first.parent.parent.text.squish
    assert_includes glance, "First aired: June 1, 1990"
    assert_includes glance, "Naked and Afraid Season 1"
    assert_includes glance, "Most recent episode:"
    assert_select "a[href=?]", season_path(@first.season)
  end

  test "/seasons FAQ is visible, matches the JSON-LD and says what the data says" do
    get seasons_path
    a = answers
    assert_includes a.keys, "How many seasons of Naked and Afraid are there?"
    assert_match(/original Naked and Afraid series has 2 seasons\./, a["How many seasons of Naked and Afraid are there?"])
    assert_match(/Counting the #{Series.count - 1} spin-offs, there are #{Season.count} seasons across #{Series.count} series\./, a["How many seasons of Naked and Afraid are there?"])
    assert_includes a["How many episodes of Naked and Afraid are there?"], "3 episodes of the original series and #{Episode.count} episodes across every series"
    assert_includes a["When did Naked and Afraid first air?"], "“The Very First”"
    assert_includes a["When did Naked and Afraid first air?"], "June 1, 1990"
    assert_includes a.keys, "In what order should I watch the seasons?"
    visible = css_select(".faq-item h3").map { |n| n.text.strip }
    assert_equal faq["mainEntity"].map { |q| q["name"] }, visible
  end

  test "/series title, description, timeline in order of first airing and FAQ" do
    get series_index_path
    assert_response :success
    assert_equal "Naked and Afraid Series in Order: Every Spin-off", title
    assert_operator description.length, :<=, 160
    assert_includes description, "#{Series.count} series, #{Season.count} seasons, #{Episode.count} episodes"

    rows = css_select("#series-in-order-heading").first.parent.parent.css("tbody tr").map { |tr| tr.css("td").map { |td| td.text.strip } }
    names = rows.map { |r| r[1] }
    # chronological by earliest air_date; the flagship (1990) before the spin-off (1995), the late series (1999) after
    assert_operator names.index("Naked and Afraid"), :<, names.index("Naked and Afraid Guide Spin")
    assert_operator names.index("Naked and Afraid Guide Spin"), :<, names.index("Naked and Afraid Guide Late")
    flagship_row = rows.find { |r| r[1] == "Naked and Afraid" }
    assert_equal [ "Jun 1990", "2", "3", "2" ], flagship_row[2..5]
    assert_equal (1..rows.size).map(&:to_s), rows.map(&:first)

    a = answers
    assert_match(/Besides the original Naked and Afraid, our guide lists .*Naked and Afraid Guide Spin/, a["What are the Naked and Afraid spin-offs?"])
    assert_includes a["How many Naked and Afraid series are there?"], "#{Series.count} series, with #{Season.count} seasons and #{Episode.count} episodes"
    assert_includes a["In what order should I watch the Naked and Afraid series?"], "Naked and Afraid (1990)"
    assert_match(/filmed in \d+ countries?/, a["Where was Naked and Afraid filmed?"])
    assert_select "section[aria-labelledby=series-faq-heading] .faq-item", faq["mainEntity"].size
    # the old content stays
    assert_select ".list-group-item", text: /Naked and Afraid Guide Late/
  end

  def purge_everything
    AppearanceItem.delete_all
    Appearance.delete_all
    Episode.delete_all
    Season.delete_all
    Series.delete_all
    Rails.cache.clear
  end

  test "counts are pluralized correctly for one season, one episode, one series" do
    purge_everything
    series = Series.create!(name: "Naked and Afraid")
    Episode.create!(season: Season.create!(series: series, number: 1, year: 1990), number_in_season: 1, title: "Only", air_date: Date.new(1990, 1, 1), location: @loc1)
    get seasons_path
    a = answers
    assert_equal "There is 1 season of Naked and Afraid.", a["How many seasons of Naked and Afraid are there?"]
    assert_equal "Our guide lists 1 episode.", a["How many episodes of Naked and Afraid are there?"]
    assert_includes description, "All 1 Naked and Afraid season (1 episode)"
    assert_no_match(/spin-off/, a.keys.join)
    get series_index_path
    a = answers
    assert_equal "Our guide covers 1 series, with 1 season and 1 episode in total.", a["How many Naked and Afraid series are there?"]
    assert_not_includes a.keys, "What are the Naked and Afraid spin-offs?"
  end

  test "franchise stats are cached and rebuilt when an episode changes" do
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    computes = 0
    counter = ->(*, payload) { computes += 1 if payload[:sql].to_s.include?("MIN(episodes.air_date)") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      first = FranchiseStats.fetch
      assert_equal first, FranchiseStats.fetch
      assert_equal 1, computes, "second call must come from the cache"
      @first.update!(air_date: Date.new(1989, 1, 1))
      assert_equal Date.new(1989, 1, 1), FranchiseStats.fetch[:first_aired][:date]
      assert_equal 2, computes
    end
  ensure
    Rails.cache = original
  end

  test "timeline is empty-safe: no series means no guide blocks" do
    purge_everything
    get series_index_path
    assert_response :success
    assert_select "#quick-answers-heading", false
    assert_select ".faq-item", 0
    get seasons_path
    assert_response :success
    assert_select "#quick-answers-heading", false
  end

  test "the /seasons table no longer runs a count query per season" do
    n = 0
    counter = ->(*, payload) { n += 1 if payload[:sql].to_s.include?("COUNT(*) FROM \"episodes\"") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get seasons_path }
    assert_equal 0, n
  end
end
