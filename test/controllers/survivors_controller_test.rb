require "test_helper"

class SurvivorsControllerTest < ActionDispatch::IntegrationTest
  test "the current slug renders" do
    get survivor_path(survivors(:one))
    assert_response :success
  end

  test "a numeric id still renders without redirecting" do
    get "/survivors/#{survivors(:one).id}"
    assert_response :success
  end

  test "an old slug 301s to the current one after a rename" do
    s = Survivor.create!(full_name: "Joesph Prouse")
    old_slug = s.slug
    s.update!(full_name: "Joseph Prouse")

    get "/survivors/#{old_slug}"

    assert_response :moved_permanently
    assert_redirected_to "/survivors/#{s.slug}"
  end

  test "an unknown slug is a 404, not a redirect" do
    get "/survivors/no-such-person"
    assert_response :not_found
  end

  test "% and _ in a survivor search are literal characters" do
    Survivor.create!(full_name: "Wildcard Tester")
    get survivors_path(q: "%")
    assert_response :success
    assert_no_match(/Wildcard Tester/, response.body)

    get survivors_path(q: "W_ldcard")
    assert_no_match(/Wildcard Tester/, response.body)

    get survivors_path(q: "ildcard")
    assert_match(/Wildcard Tester/, response.body)
  end

  test "search misses are cached under a bounded key, not the raw query" do
    was = Rails.cache
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.cache = store
    begin
      long = "nomatch" * 200
      get survivors_path(q: long)
      assert_response :success
      keys = store.instance_variable_get(:@data).keys
      assert keys.any? { |k| k.start_with?("survivors_search_hit/") }
      assert keys.none? { |k| k.include?("nomatch") }, "raw query must not appear in a cache key"
      assert keys.all? { |k| k.length < 100 }
    ensure
      Rails.cache = was
    end
  end

  # ----- watch links + explore links -----

  def build_cast(series_name: "Naked and Afraid", season_number: 14, country: "Colombia")
    series = Series.find_or_create_by!(name: series_name)
    season = Season.find_or_create_by!(series: series, number: season_number)
    loc    = Location.create!(country: country)
    ep     = Episode.create!(season: season, number_in_season: 1, title: "Cast Ep #{season_number}", location: loc)
    [season, ep]
  end

  test "lists where to watch the seasons a survivor was on, with streaming links" do
    me = Survivor.create!(full_name: "Watch Tester")
    _season, ep = build_cast(season_number: 14)
    Appearance.create!(survivor: me, episode: ep)

    get survivor_path(me)
    assert_response :success
    assert_select "#survivor-watch-heading", text: "Where to Watch Watch's Season"
    assert_select "section[aria-labelledby=survivor-watch-heading] a[href='https://www.discoveryplus.com/']", text: "Discovery+"
    assert_select "section[aria-labelledby=survivor-watch-heading] a[href='https://www.hulu.com/']", text: "Hulu"
  end

  test "long watch lists show six seasons and tuck the rest into a details block" do
    me = Survivor.create!(full_name: "Veteran Tester")
    (1..8).each do |n|
      _season, ep = build_cast(season_number: n)
      Appearance.create!(survivor: me, episode: ep)
    end

    get survivor_path(me)
    assert_response :success
    assert_select "section[aria-labelledby=survivor-watch-heading] > ul > li", 6
    assert_select "details.survivor-watch-more summary", text: "Show 2 more seasons"
    assert_select "details.survivor-watch-more li", 2
  end

  test "the watch card is hidden when no streaming data exists for their seasons" do
    me = Survivor.create!(full_name: "Nowhere Tester")
    _season, ep = build_cast(series_name: "Naked and Afraid Unlisted", season_number: 1)
    Appearance.create!(survivor: me, episode: ep)

    get survivor_path(me)
    assert_response :success
    assert_select "#survivor-watch-heading", false
  end

  test "links to other survivors from the same season and the same country" do
    me      = Survivor.create!(full_name: "Anchor Person")
    mate    = Survivor.create!(full_name: "Season Mate")
    s14, e14 = build_cast(season_number: 14, country: "Colombia")
    Appearance.create!(survivor: me, episode: e14)
    # Same season, different episode: not a co-star, so not in the related list.
    e14b = Episode.create!(season: s14, number_in_season: 2, title: "Other pair", location: e14.location)
    Appearance.create!(survivor: mate, episode: e14b)

    other_season_ep = Episode.create!(season: Season.find_or_create_by!(series: Series.find_by!(name: "Naked and Afraid"), number: 15),
                                      number_in_season: 1, title: "Elsewhere", location: Location.create!(country: "colombia"))
    country_mate = Survivor.create!(full_name: "Country Mate")
    Appearance.create!(survivor: country_mate, episode: other_season_ep)

    Rails.cache.clear
    get survivor_path(me)
    assert_response :success
    assert_select "#explore-heading"
    assert_select "section[aria-labelledby=explore-heading] a[href='#{survivor_path(mate)}']", text: "Season Mate"
    assert_select "section[aria-labelledby=explore-heading] a[href='#{survivor_path(country_mate)}']", text: "Country Mate"
    assert_select "section[aria-labelledby=explore-heading] a[href='/episodes/by_country/colombia']"
    assert_select "section[aria-labelledby=explore-heading] a[href='#{survivor_path(me)}']", false
  end

  test "no explore section when there is nobody else to link to" do
    me = Survivor.create!(full_name: "Lonely Tester")
    _season, ep = build_cast(season_number: 3, country: "Peru")
    Appearance.create!(survivor: me, episode: ep)

    Rails.cache.clear
    get survivor_path(me)
    assert_response :success
    assert_select "#explore-heading", false
  end
end
