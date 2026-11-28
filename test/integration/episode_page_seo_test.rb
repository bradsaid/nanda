require "test_helper"

# Episode pages name the series, season and episode number in the title, subtitle and
# description ("Season 11 Episode 4" searches) while the H1 stays the episode title.
class EpisodePageSeoTest < ActionDispatch::IntegrationTest
  def title = css_select("head title").first.text
  def description = css_select('head meta[name="description"]').first["content"]
  def json_ld = css_select('script[type="application/ld+json"]').flat_map { |n| p = JSON.parse(n.text); p.is_a?(Array) ? p : [ p ] }

  setup do
    @loc = Location.create!(country: "Colombia", region: "Choco", site: "Camp", latitude: 5.5, longitude: -76.7)
  end

  def episode_in(series_name, season_number, number, title, **attrs)
    series = Series.find_or_create_by!(name: series_name)
    season = Season.find_or_create_by!(series: series, number: season_number) { |s| s.year = 2020 }
    Episode.create!({ season: season, number_in_season: number, title: title, location: @loc }.merge(attrs))
  end

  test "flagship episode: title, h1, subtitle and description" do
    ep = episode_in("Naked and Afraid", 14, 2, "Haunted and Hungry", air_date: Date.new(2022, 1, 5),
                    synopsis: "Two survivalists land in the jungle and must find water before nightfall.")
    get episode_path(ep)
    assert_response :success
    assert_equal "Naked and Afraid Season 14 Episode 2: Haunted and Hungry", title
    assert_equal [ "Haunted and Hungry" ], css_select("h1").map { |h| h.text.strip }
    sub = css_select("h1").first.parent.at_css("p.text-muted").text.squish
    assert_equal "Naked and Afraid · Season 14 · Episode 2 · Aired Jan 5, 2022", sub
    assert_select "h1 ~ p a[href=?]", season_path(ep.season), text: "Naked and Afraid · Season 14"
    assert_equal "Naked and Afraid Season 14 Episode 2 aired Jan 5, 2022 in Choco, Colombia. Two survivalists land in the jungle and must find water before nightfall.", description
    assert_operator description.length, :<=, 160
    assert_equal "Naked and Afraid Season 14 Episode 2: Haunted and Hungry", css_select('meta[property="og:title"]').first["content"]
  end

  test "spin-off episode names the series, not just the season number" do
    ep = episode_in("Naked and Afraid Shipwrecked", 1, 1, "Abandon Ship", air_date: Date.new(2022, 7, 22))
    get episode_path(ep)
    # "…Season 1 Episode 1: Abandon Ship" is 61 characters (cap 60, was 65), so the compact code is used
    assert_equal "Naked and Afraid Shipwrecked S1E1: Abandon Ship", title
    assert_equal "Naked and Afraid Shipwrecked · Season 1 · Episode 1 · Aired Jul 22, 2022", css_select("h1").first.parent.at_css("p.text-muted").text.squish
    # no synopsis: the factual line plus the standard tail
    assert_equal "Naked and Afraid Shipwrecked Season 1 Episode 1 aired Jul 22, 2022 in Choco, Colombia. Participants, PSR, days lasted and items.", description
  end

  test "a colon in the series name does not double up in the title" do
    ep = episode_in("Naked and Afraid: Global Showdown", 1, 8, "Sharp Spears, Broken Spirits", air_date: Date.new(2023, 3, 1))
    get episode_path(ep)
    # 67 characters in full (cap 60, was 65): the series name and episode code stay, the episode title is cut at a word
    assert_equal "Naked and Afraid Global Showdown S1E8: Sharp Spears, Broken…", title
    assert_not_includes title, ": Global"
  end

  test "long synopsis is cut to the description limit and a missing air date is left out" do
    ep = episode_in("Naked and Afraid XL", 10, 3, "No Date", synopsis: "A very long story. " * 40)
    get episode_path(ep)
    assert_operator description.length, :<=, 160
    assert description.start_with?("Naked and Afraid XL Season 10 Episode 3 in Choco, Colombia. A very long story.")
    assert_not_includes description, "—"
    assert_equal "Naked and Afraid XL · Season 10 · Episode 3", css_select("h1").first.parent.at_css("p.text-muted").text.squish
  end

  test "TVEpisode JSON-LD keeps the plain episode title and a valid season name" do
    ep = episode_in("Naked and Afraid XL", 4, 1, "Frozen Start", air_date: Date.new(2020, 2, 2))
    get episode_path(ep)
    tv = json_ld.find { |s| s["@type"] == "TVEpisode" }
    assert_equal "Frozen Start", tv["name"]
    assert_equal "Naked and Afraid XL Season 4", tv["partOfSeason"]["name"]
    assert_equal 1, tv["episodeNumber"]
  end
end
