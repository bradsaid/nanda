require "test_helper"

# /series/:id is a hub: Q&A (visible + FAQPage JSON-LD), episode list with recap excerpts, cast,
# a weight-loss table only when some appearance has weight_loss, and no statistic without data.
class SeriesHubPageTest < ActionDispatch::IntegrationTest
  def title = css_select("head title").first.text
  def description = css_select('head meta[name="description"]').first["content"]
  def json_ld = css_select('script[type="application/ld+json"]').flat_map { |n| p = JSON.parse(n.text); p.is_a?(Array) ? p : [ p ] }
  def schema(type) = json_ld.find { |s| s["@type"] == type }
  def answers = schema("FAQPage")["mainEntity"].to_h { |q| [ q["name"], CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(q["acceptedAnswer"]["text"])).squish ] }

  LONG_SYNOPSIS = ("The castaways wake up on a remote island and quickly discover that finding water is harder than they thought. " * 3).strip.freeze

  setup do
    @loc = Location.create!(country: "Panama", region: "Bocas", site: "Island Camp", latitude: 9.3, longitude: -82.2)
    @series = Series.create!(name: "Naked and Afraid Shipwrecked", continuous_story: true)
    @season = Season.create!(series: @series, number: 1, year: 2022, continuous_story: true)
    @e1 = Episode.create!(season: @season, number_in_season: 1, title: "Abandon Ship", air_date: Date.new(2022, 7, 22), location: @loc,
                          scheduled_days: 40, participant_arrangement: "2+2+2", synopsis: LONG_SYNOPSIS)
    @e2 = Episode.create!(season: @season, number_in_season: 2, title: "Adrift", air_date: Date.new(2022, 7, 29), location: @loc, scheduled_days: 40)
    @ann = Survivor.create!(full_name: "Hub Ann")
    @bob = Survivor.create!(full_name: "Hub Bob")
    @a1 = Appearance.create!(episode: @e1, survivor: @ann)
    @a2 = Appearance.create!(episode: @e1, survivor: @bob)
  end

  test "title, description and h1 for a single-season series" do
    get series_path(@series)
    assert_response :success
    # the "…, Location & Dates" wording is 61 characters (cap 60, was 65), so the next wording is used
    assert_equal "Naked and Afraid Shipwrecked: Episodes, Cast & Location", title
    assert_operator title.length, :<=, SeoHelper::MAX_TITLE_LENGTH
    assert_equal "Naked and Afraid Shipwrecked", css_select("h1").map { |h| h.text.strip }.first
    assert_equal 1, css_select("h1").size
    assert_equal "Naked and Afraid Shipwrecked: 2 episodes, premiering Jul 22, 2022. Filmed in Panama. Episode list, cast, air dates and where to watch.", description
    assert_operator description.length, :<=, 160
  end

  test "title falls back to a shorter form when the series name is long" do
    long = Series.create!(name: "Naked and Afraid: Global Showdown")
    get series_path(long)
    assert_equal "Naked and Afraid Global Showdown: Episodes, Cast & Location", title
    assert_operator title.length, :<=, 65
  end

  test "Q&A is visible and the FAQPage JSON-LD parses with the same questions and answers" do
    get series_path(@series)
    qa = answers
    assert_equal "Naked and Afraid Shipwrecked premiered on July 22, 2022 with “Abandon Ship”.", qa["When did Naked and Afraid Shipwrecked premiere?"]
    assert_equal "Naked and Afraid Shipwrecked has 2 episodes, aired from July 22, 2022 to July 29, 2022.", qa["How many episodes are in Naked and Afraid Shipwrecked?"]
    assert_match(/was filmed in Panama\. Filming location: Island Camp, Bocas, Panama\./, qa["Where was Naked and Afraid Shipwrecked filmed?"])
    assert_equal "The 2 survivalists in Naked and Afraid Shipwrecked are Hub Ann and Hub Bob.", qa["Who is in the cast of Naked and Afraid Shipwrecked?"]
    assert_equal "The challenge in Naked and Afraid Shipwrecked is scheduled for 40 days.", qa["How many days is the challenge in Naked and Afraid Shipwrecked?"]
    assert_equal "Our episode data records 3 teams (arrangement 2+2+2).", qa["How many teams are in Naked and Afraid Shipwrecked?"]
    assert_match(/on Discovery GO and Max\./, qa["Where can I watch Naked and Afraid Shipwrecked?"])
    assert_not(qa.keys.any? { |q| q.start_with?("Who tapped out") }, "no results are recorded")

    visible = css_select(".faq-item").to_h { |n| [ n.at_css("h3").text.strip, n.at_css("p").text.squish ] }
    assert_equal qa, visible

    assert_equal "Naked and Afraid Shipwrecked", schema("TVSeries")["name"]
    assert_equal 2, schema("TVSeries")["numberOfEpisodes"]
    assert_equal "2022-07-22", schema("TVSeries")["startDate"]
    assert_equal "Series", schema("BreadcrumbList")["itemListElement"][1]["name"]
  end

  test "episode list shows air date, location and a ~160 character recap excerpt" do
    get series_path(@series)
    assert_select "h3 a[href=?]", episode_path(@e1), text: "Abandon Ship"
    card = css_select("h3 a").find { |a| a.text == "Abandon Ship" }.ancestors(".card").first
    assert_includes card.text, "Jul 22, 2022"
    assert_includes card.text, "Panama • Bocas • Island Camp"
    excerpt = card.at_css("p.small").text.strip
    assert_operator excerpt.length, :<=, 160
    assert excerpt.end_with?("…")
    assert LONG_SYNOPSIS.start_with?(excerpt.delete_suffix("…").strip)
    assert_select "span.badge", text: "E1" # a single-season series needs no season prefix
    adrift = css_select("h3 a").find { |a| a.text == "Adrift" }.ancestors(".card").first
    assert_nil adrift.at_css("p.small"), "no synopsis, no excerpt"
  end

  test "cast section lists the survivalists and notes that teams are not recorded" do
    get series_path(@series)
    assert_select "#series-cast-heading", /cast \(2\)/
    assert_select "section[aria-labelledby=series-cast-heading] a[href=?]", survivor_path(@ann)
    assert_select "section[aria-labelledby=series-cast-heading]", text: /3 teams.*not recorded/
  end

  test "weight-loss table appears only when an appearance has weight_loss" do
    get series_path(@series)
    assert_select "#weight-loss", false
    assert_no_match(/weight loss/i, css_select("h2").map(&:text).join(" "))

    @a1.update!(weight_loss: 12)
    @a2.update!(weight_loss: 17)
    get series_path(@series)
    assert_select "#weight-loss table" do
      rows = css_select("#weight-loss tbody tr").map { |tr| tr.css("td").map { |td| td.text.squish } }
      assert_equal [ [ "Hub Bob", "E1: Abandon Ship", "17 lbs" ], [ "Hub Ann", "E1: Abandon Ship", "12 lbs" ] ], rows # largest first
    end
  end

  test "a result adds the tap-out answer and the highlights block" do
    @a1.update!(result: "tap_out")
    @a2.update!(result: "success")
    get series_path(@series)
    assert_includes answers["Who tapped out in Naked and Afraid Shipwrecked?"], "recorded result for 2 of 2 survivalists"
    assert_includes answers["Who tapped out in Naked and Afraid Shipwrecked?"], "tapped out: Hub Ann"
    assert_select "section[aria-labelledby=series-highlights-heading] li", /Tapped out:\s*Hub Ann/
  end

  test "a multi-season series labels episodes with the season, lists cast per season and has no single watch card" do
    series = Series.create!(name: "Hub Multi")
    s1 = Season.create!(series: series, number: 1, year: 2020)
    s2 = Season.create!(series: series, number: 2, year: 2021)
    Episode.create!(season: s1, number_in_season: 1, title: "M One", air_date: Date.new(2020, 1, 1), location: @loc)
    Episode.create!(season: s2, number_in_season: 1, title: "M Two", air_date: Date.new(2021, 1, 1), location: @loc)
    get series_path(series)
    assert_select "span.badge", text: "S1E1"
    assert_select "span.badge", text: "S2E1"
    assert_includes answers["How many episodes are in Hub Multi?"], "2 episodes across 2 seasons"
    assert_equal "Hub Multi: 2 episodes in 2 seasons, premiering Jan 1, 2020. Filmed in Panama. Episode list, cast, air dates and where to watch.", description
  end

  test "a series without data leaves unknowns out instead of printing zeros" do
    empty = Series.create!(name: "Hub Empty")
    get series_path(empty)
    assert_response :success
    assert_equal "Hub Empty: seasons, episodes, cast and where to watch.", description
    assert_select ".faq-item", 0
    assert_select "#weight-loss", false
    assert_equal 1, css_select("h1").size
  end

  test "big series skip the full episode list, and the page stays query-bounded" do
    big = Series.create!(name: "Hub Big")
    season = Season.create!(series: big, number: 1, year: 2020)
    (SeriesController::EPISODE_LIST_LIMIT + 1).times do |i|
      ep = Episode.create!(season: season, number_in_season: i + 1, title: "Big #{i}", air_date: Date.new(2020, 1, 1) + i, location: @loc)
      Appearance.create!(episode: ep, survivor: Survivor.create!(full_name: "Big Person #{i}"))
    end
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get series_path(big) }
    assert_response :success
    assert_select "h3 a[href*='/episodes/']", false
    assert_select "#series-cast-heading", /cast \(61\)/ # 61 is within CAST_LIST_LIMIT
    assert_operator queries, :<=, 20
    assert_equal "Hub Big has 61 survivalists; the full cast is listed on this page.", answers["Who is in the cast of Hub Big?"]
  end
end
