require "test_helper"

# /seasons/latest: data-driven, relative to today (Date.current, Central time); upcoming vs
# aired episodes, a next-unaired highlight, FAQ answered from air dates only.
class LatestSeasonTest < ActionDispatch::IntegrationTest
  NOW = Time.zone.local(2026, 11, 27, 12, 0, 0) # a Friday; the week is Nov 23 - 29

  setup do
    Rails.cache.clear
    @today  = NOW.to_date
    @series = Series.create!(name: "Latest Test Series")
    @season = Season.create!(series: @series, number: 5, year: 2026)
    @loc    = Location.create!(country: "Panama", region: "Darien", site: "Camp Latest", latitude: 8.0, longitude: -80.0)
    @aired1 = ep(1, "Aired One",   @today - 14)
    @aired2 = ep(2, "Aired Two",   @today - 7)
    @soon   = ep(3, "Coming Soon", @today + 7)
    @later  = ep(4, "Coming Later", @today + 14)
  end

  def ep(n, title, date, season: @season)
    Episode.create!(season: season, number_in_season: n, title: title, location: @loc, air_date: date)
  end

  def run_at(&block) = travel_to(NOW, &block)

  def title = css_select("head title").first.text
  def description = css_select('head meta[name="description"]').first["content"]
  def canonical = css_select("link[rel=canonical]").first["href"]
  def json_ld = css_select('script[type="application/ld+json"]').map { |n| JSON.parse(n.text) }.flatten
  def faq_answers = json_ld.find { |n| n["@type"] == "FAQPage" }["mainEntity"].to_h { |q| [q["name"], ActionController::Base.helpers.strip_tags(q["acceptedAnswer"]["text"])] }

  test "renders with the title, heading and a clean canonical" do
    run_at do
      get "/seasons/latest"
      assert_response :success
      assert_equal "Latest Naked and Afraid Season: Episodes & Air Dates", css_select("h1").first.text
      assert_select "h1", count: 1
      assert_match "Latest Naked and Afraid Season: Episodes & Air Dates", title
      assert_equal "http://www.example.com/seasons/latest", canonical
      assert_operator description.length, :<=, 160
      assert_match "Latest Test Series Season 5", description
      assert_operator ApplicationController.helpers.latest_meta_description(LatestSeasonGuide::Result.new(active: [], others: [], week_episodes: [])).length, :<=, 160
    end
  end

  test "/seasons/latest is not captured by /seasons/:id, and real season ids still work" do
    assert_recognizes({ controller: "latest_seasons", action: "show" }, "/seasons/latest")
    assert_recognizes({ controller: "seasons", action: "show", id: "12" }, "/seasons/12")
    get season_path(@season)
    assert_response :success
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/seasons/#{@season.id}"
  end

  test "?page and other params do not change the canonical" do
    run_at do
      get "/seasons/latest?page=2&utm=x"
      assert_equal "http://www.example.com/seasons/latest", canonical
    end
  end

  test "the season's episodes are marked Aired or Upcoming relative to today" do
    run_at do
      get "/seasons/latest"
      rows = css_select("section.latest-season tbody tr").to_h { |tr| [tr.at_css("td[data-label=Episode]").text.strip, tr.at_css("td[data-label=Status]").text.strip] }
      assert_equal "Aired",    rows["Aired One"]
      assert_equal "Aired",    rows["Aired Two"]
      assert_equal "Upcoming", rows["Coming Soon"]
      assert_equal "Upcoming", rows["Coming Later"]
      assert_select "td[data-label=Location]", text: "Panama, Darien, Camp Latest", minimum: 1
      assert_select "a[href=?]", episode_path(@soon)
    end
  end

  test "an episode dated today is 'Airs today', not Aired, and is not the last aired episode" do
    run_at do
      tonight = ep(9, "Tonight", @today)
      get "/seasons/latest"
      status = css_select("section.latest-season tbody tr").find { |tr| tr.text.include?("Tonight") }.at_css("td[data-label=Status]").text.strip
      assert_equal "Airs today", status
      assert_match(/Aired Two/, faq_answers["When was the most recent Naked and Afraid episode aired?"])
      assert_select ".latest-next h2", text: "Tonight"
    ensure
      tonight&.destroy
    end
  end

  test "the next unaired episode is highlighted: the earliest future-dated one" do
    run_at do
      get "/seasons/latest"
      assert_select ".latest-next" do
        assert_select "h2 a[href=?]", episode_path(@soon), text: "Coming Soon"
        assert_select ".badge", text: "Upcoming"
        assert_select "*", text: /December 4, 2026/
      end
    end
  end

  test "quick answers come from the air dates and match the FAQPage JSON-LD" do
    run_at do
      get "/seasons/latest"
      answers = faq_answers
      assert_equal "The most recently aired season in our database is Latest Test Series Season 5; its newest aired episode is dated November 20, 2026.",
                   answers["What is the latest Naked and Afraid season?"]
      assert_equal "The most recent episode in our database to have aired is \"Aired Two\" (Latest Test Series Season 5, Episode 2), dated November 20, 2026.",
                   answers["When was the most recent Naked and Afraid episode aired?"]
      assert_equal "The next episode in our database is \"Coming Soon\" (Latest Test Series Season 5, Episode 3), dated December 4, 2026.",
                   answers["When is the next Naked and Afraid episode?"]
      assert_equal "No episode in our database is dated this week (November 23 to November 29). The most recent episode that has aired is dated November 20, 2026.",
                   answers["Is there a new Naked and Afraid episode this week?"]
      answers.each_key { |q| assert_select "details summary", text: q }
    end
  end

  test "'new episode this week' says yes only when an episode is dated Monday to Sunday of this week" do
    run_at do
      ep(6, "This Week Ep", @today - 2) # Wednesday Nov 25
      get "/seasons/latest"
      answer = faq_answers["Is there a new Naked and Afraid episode this week?"]
      assert_match(/\AYes\. In our database: "This Week Ep" \(Latest Test Series Season 5\) aired November 25, 2026\./, answer)

      Episode.find_by(title: "This Week Ep").update!(air_date: Date.new(2026, 11, 30)) # next Monday: outside the week
      get "/seasons/latest"
      assert_match(/\ANo episode in our database is dated this week/, faq_answers["Is there a new Naked and Afraid episode this week?"])
    end
  end

  test "with nothing upcoming there is no highlight and the answer is neutral, never a claim about announcements" do
    run_at do
      [@soon, @later].each(&:destroy)
      get "/seasons/latest"
      assert_select ".latest-next", 0
      assert_equal "No upcoming episode is listed in our database right now. New seasons and episodes are added as soon as they are announced.",
                   faq_answers["When is the next Naked and Afraid episode?"]
      body = response.body
      assert_match "We add every new season and episode as soon as it is announced; seasons not listed here have not been added to the database yet.", body
      assert_no_match(/has not been announced|not yet announced|will premiere|premieres on|renewed/i, body)
    end
  end

  test "active series show their latest season in full; stale series appear in the compact list" do
    run_at do
      get "/seasons/latest"
      assert_select "section.latest-season", count: 1
      assert_select "section.latest-season h2", text: "Latest Test Series Season 5"
      # The fixture series' episodes are from September 2025: more than a year ago.
      assert_select "#latest-others-heading"
      assert_select "section[aria-labelledby=latest-others-heading] li a[href=?]", season_path(seasons(:one)), text: "TestSeriesA Season 1"
      assert_select "section[aria-labelledby=latest-others-heading] li", text: /latest episode dated Sep 10, 2025/
    end
  end

  test "a series whose latest season is newer than an older season of the same series shows only the newer one" do
    run_at do
      older = Season.create!(series: @series, number: 4, year: 2025)
      ep(1, "Old Season Ep", Date.new(2026, 3, 1), season: older)
      get "/seasons/latest"
      assert_select "section.latest-season", count: 1
      assert_select "section.latest-season h2", text: "Latest Test Series Season 5"
      assert_no_match(/Old Season Ep/, response.body)
    end
  end

  test "when no series is active the single most recent one is still shown" do
    travel_to(Time.zone.local(2030, 1, 15, 12)) do
      get "/seasons/latest"
      assert_response :success
      assert_select "section.latest-season", count: 1
      assert_select "section.latest-season h2", text: "Latest Test Series Season 5"
    end
  end

  test "an empty database renders a neutral page" do
    run_at do
      AppearanceItem.delete_all
      Appearance.delete_all
      Episode.delete_all
      get "/seasons/latest"
      assert_response :success
      assert_select "section.latest-season", 0
      assert_match "No dated episodes have been added yet.", response.body
    end
  end

  test "the page is listed in the sitemap and linked from the home page's latest episode block" do
    get "/sitemap.xml"
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
    assert_includes locs, "https://www.nakedandafraidfan.com/seasons/latest"

    get "/"
    assert_select "a[href=?]", "/seasons/latest", text: /Latest season/
  end

  test "ItemList JSON-LD matches the episodes shown" do
    run_at do
      get "/seasons/latest"
      list = json_ld.find { |n| n["@type"] == "ItemList" }
      assert_equal 4, list["numberOfItems"]
      assert_equal ["Aired One", "Aired Two", "Coming Soon", "Coming Later"], list["itemListElement"].map { |i| i["name"] }
    end
  end

  test "status helper" do
    assert_equal :upcoming, LatestSeasonGuide.status(@today + 1, @today)
    assert_equal :today,    LatestSeasonGuide.status(@today, @today)
    assert_equal :aired,    LatestSeasonGuide.status(@today - 1, @today)
    assert_nil LatestSeasonGuide.status(nil, @today)
  end
end
