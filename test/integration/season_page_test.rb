require "test_helper"

# /seasons/:id answers the searches behind it: cast, premiere/finale, episode count, where it
# was filmed, format, where to watch, with the series always in the name so XL season N is
# never mistaken for regular season N. Every statistic comes from the data and is left out
# when the data is missing.
class SeasonPageTest < ActionDispatch::IntegrationTest
  def title = css_select("head title").first.text
  def description = css_select('head meta[name="description"]').first["content"]
  def json_ld = css_select('script[type="application/ld+json"]').flat_map { |n| p = JSON.parse(n.text); p.is_a?(Array) ? p : [ p ] }
  def schema(type) = json_ld.find { |s| s["@type"] == type }
  # The value shown next to a label in the "at a glance" card, or nil when the row is absent.
  def fact(label) = css_select("dt").find { |d| d.text.strip == label }&.next_element&.text&.squish

  setup do
    @panama   = Location.create!(country: "Panama", region: "Darien", site: "Camp One", latitude: 8.5, longitude: -78.0)
    @colombia = Location.create!(country: "Colombia", region: "Choco", site: "Camp Two", latitude: 5.5, longitude: -76.7)
    @regular  = Series.create!(name: "Naked and Afraid")
    @xl       = Series.create!(name: "Naked and Afraid XL", continuous_story: true)

    @s10 = Season.create!(series: @regular, number: 10, year: 2020)
    @s11 = Season.create!(series: @regular, number: 11, year: 2021)
    @s12 = Season.create!(series: @regular, number: 12, year: 2022)
    @xl10 = Season.create!(series: @xl, number: 10, year: 2023, continuous_story: true)

    @ann = Survivor.create!(full_name: "Ann Alpha")
    @bob = Survivor.create!(full_name: "Bob Bravo")
    @cy  = Survivor.create!(full_name: "Cy Charlie")

    @e1 = Episode.create!(season: @s11, number_in_season: 1, title: "First Dropoff", air_date: Date.new(2021, 3, 5), location: @panama, scheduled_days: 21)
    @e2 = Episode.create!(season: @s11, number_in_season: 2, title: "Second Dropoff", air_date: Date.new(2021, 3, 12), location: @colombia, scheduled_days: 21)
    @a1 = Appearance.create!(episode: @e1, survivor: @ann)
    @a2 = Appearance.create!(episode: @e1, survivor: @bob)
    Appearance.create!(episode: @e2, survivor: @cy)

    @xe1 = Episode.create!(season: @xl10, number_in_season: 1, title: "Xl One", air_date: Date.new(2023, 5, 1), location: @panama, scheduled_days: 40)
    Appearance.create!(episode: @xe1, survivor: @ann)
  end

  test "regular season: title, h1, description and breadcrumb name the series and the intent" do
    get season_path(@s11)
    assert_response :success
    assert_equal "Naked and Afraid Season 11: Cast, Episodes & Locations", title
    assert_operator title.length, :<=, 65
    assert_equal [ "Naked and Afraid Season 11" ], css_select("h1").map { |h| h.text.strip }
    assert_match(/\ANaked and Afraid Season 11 \(2021\): 2 episodes filmed in Panama and Colombia with 3 survivalists\./, description)
    assert_operator description.length, :<=, 160
    assert_select "nav[aria-label=Breadcrumb]", /Seasons\s*»\s*Naked and Afraid Season 11/
  end

  test "XL season 10 is clearly different from regular season 10" do
    get season_path(@xl10)
    assert_equal "Naked and Afraid XL Season 10: Cast, Episodes & Locations", title
    assert_equal "Naked and Afraid XL Season 10", css_select("h1").first.text.strip
    assert_match(/\ANaked and Afraid XL Season 10 \(2023\)/, description)
    xl_title = title

    get season_path(@s10)
    assert_equal "Naked and Afraid Season 10: Cast, Episodes & Locations", title
    assert_not_equal xl_title, title
    # a season with no episodes: no invented numbers
    assert_equal "Naked and Afraid Season 10: episode guide, cast and where to watch.", description
    assert_select "#season-facts-heading", false
  end

  test "season page shows premiere, finale, episodes, countries, days, format and cast" do
    get season_path(@s11)
    assert_equal "March 5, 2021", fact("Premiere")
    assert_equal "March 12, 2021", fact("Finale")
    assert_equal "2", fact("Episodes")
    assert_equal "Panama, Colombia", fact("Filmed in")
    assert_equal "21 days", fact("Challenge length")
    assert_match(/\AStandalone episodes/, fact("Format"))
    assert_equal "3 survivalists", fact("Cast")
    assert_equal "Naked and Afraid", fact("Series")
    assert_select "a[href*=?]", "/episodes/by_country/"
    assert_select "a[href=?]", survivor_path(@ann)

    get season_path(@xl10)
    assert_match(/\AContinuous story/, fact("Format"))
    assert_equal "40 days", fact("Challenge length")
    assert_equal "May 1, 2023", fact("Premiere")
    assert_nil fact("Finale") # one episode: premiere only
    assert_equal "Naked and Afraid XL", fact("Series")
  end

  test "partner pairs are labelled on regular seasons only" do
    get season_path(@s11)
    assert_select ".card-body", text: /Partners:\s*Ann Alpha\s*Bob Bravo/
    assert_select ".card-body", text: /Cast:\s*Cy Charlie/
    get season_path(@xl10)
    assert_no_match(/Partners:/, response.body)
  end

  test "previous and next seasons of the same series link with rel prev/next" do
    get season_path(@s11)
    assert_select "a[rel=prev][href=?]", season_path(@s10), text: /Naked and Afraid Season 10/
    assert_select "a[rel=next][href=?]", season_path(@s12), text: /Naked and Afraid Season 12/
    get season_path(@xl10) # alone in its series: no neighbours, and never the regular series' seasons
    assert_select "a[rel=prev]", false
    assert_select "a[rel=next]", false
  end

  test "visible FAQ answers come from the data and match the FAQPage JSON-LD" do
    get season_path(@s11)
    faq = schema("FAQPage")
    questions = faq["mainEntity"].map { |q| q["name"] }
    assert_includes questions, "How many episodes are in Naked and Afraid Season 11?"
    assert_includes questions, "Where was Naked and Afraid Season 11 filmed?"
    assert_includes questions, "Who is in the cast of Naked and Afraid Season 11?"
    assert_includes questions, "Where can I watch Naked and Afraid Season 11?"
    assert_includes questions, "How many days is the challenge in Naked and Afraid Season 11?"

    answers = faq["mainEntity"].to_h { |q| [ q["name"], q["acceptedAnswer"]["text"] ] }
    assert_equal "Naked and Afraid Season 11 has 2 episodes, airing from March 5, 2021 to March 12, 2021.",
                 answers["How many episodes are in Naked and Afraid Season 11?"]
    assert_match(/filmed in .*Panama.* and .*Colombia/, answers["Where was Naked and Afraid Season 11 filmed?"])
    assert_includes answers["Who is in the cast of Naked and Afraid Season 11?"], "Ann Alpha"
    assert_includes answers["Where can I watch Naked and Afraid Season 11?"], "Discovery+"

    # Every JSON-LD question is rendered visibly, with the same plain-text answer.
    visible = css_select(".faq-item").to_h { |n| [ n.at_css("h3").text.strip, n.at_css("p").text.squish ] }
    faq["mainEntity"].each do |q|
      assert visible.key?(q["name"]), "#{q['name']} is not visible"
      assert_equal visible[q["name"]], CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(q["acceptedAnswer"]["text"])).squish
    end
    # links inside answers are absolute in the schema
    assert_match(%r{href="http://www\.example\.com/survivors/}, answers["Who is in the cast of Naked and Afraid Season 11?"])
  end

  test "results, PSR and brought items appear only when the data has them" do
    get season_path(@s11)
    assert_no_match(/Results on record/, response.body)
    assert_select "#season-highlights-heading", false
    questions = schema("FAQPage")["mainEntity"].map { |q| q["name"] }
    assert_not(questions.any? { |q| q.start_with?("Who tapped out") })
    assert_not(questions.any? { |q| q.start_with?("What was the highest PSR") })
    assert_not(questions.any? { |q| q.start_with?("What items were brought most") })

    knife = Item.create!(name: "Season Knife", item_type: "blade")
    pot   = Item.create!(name: "Season Pot", item_type: "cookware")
    @a1.update!(result: "success", ending_psr: 7.5)
    @a2.update!(result: "tap_out", ending_psr: 6)
    [ @a1, @a2 ].each { |a| AppearanceItem.create!(appearance: a, item: knife, source: "brought") }
    AppearanceItem.create!(appearance: @a1, item: pot, source: "brought")

    get season_path(@s11)
    assert_select "#season-highlights-heading", /highlights/
    assert_select "section[aria-labelledby=season-highlights-heading]" do
      assert_select "li", /Completed:\s*Ann Alpha/
      assert_select "li", /Tapped out:\s*Bob Bravo/
      assert_select "p", /Highest ending PSR on record:\s*7\.5\s*—\s*Ann Alpha/
      assert_select "li", /season knife\s*—\s*2/i
    end
    assert_match(/2 of 3 survivalists/, response.body)
    answers = schema("FAQPage")["mainEntity"].to_h { |q| [ q["name"], q["acceptedAnswer"]["text"] ] }
    assert_match(/recorded result for 2 of 3 survivalists/, answers["Who tapped out in Naked and Afraid Season 11?"])
    assert_includes answers["What was the highest PSR in Naked and Afraid Season 11?"], "7.5"
    assert_match(/season knife.*\(2\)/i, answers["What items were brought most in Naked and Afraid Season 11?"])
  end

  test "items brought once each are not presented as a ranking" do
    item = Item.create!(name: "Lonely Item", item_type: "tool")
    AppearanceItem.create!(appearance: @a1, item: item, source: "brought")
    get season_path(@s11)
    assert_no_match(/Items brought by the most survivalists/, response.body)
  end

  test "JSON-LD parses and keeps the TVSeason named after the series" do
    get season_path(@xl10)
    season = schema("TVSeason")
    assert_equal "Naked and Afraid XL – Season 10", season["name"]
    assert_equal 1, season["numberOfEpisodes"]
    assert_equal 1, json_ld.count { |s| s["@type"] == "FAQPage" }
  end

  test "season page makes no more queries for a bigger cast" do
    count_queries = lambda do |path|
      n = 0
      counter = ->(*, payload) { n += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
      n
    end
    base = count_queries.call(season_path(@s11))
    10.times do |i|
      ep = Episode.create!(season: @s11, number_in_season: 20 + i, title: "More #{i}", air_date: Date.new(2021, 4, 1) + i, location: @panama)
      Appearance.create!(episode: ep, survivor: Survivor.create!(full_name: "Extra Person #{i}"))
    end
    assert_operator count_queries.call(season_path(@s11)), :<=, base + 1
  end
end
