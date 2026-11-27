require "test_helper"

class RegionHubsTest < ActionDispatch::IntegrationTest
  HOST = "https://www.nakedandafraidfan.com".freeze

  setup do
    NameSlugs.reset!
    Rails.cache.clear
    @series = Series.create!(name: "Region Test Series")
    @season = Season.create!(series: @series, number: 3, year: 2024)
    @namibia = Location.create!(country: "Namibia", region: "Skeleton Coast", site: "Camp", latitude: -22.0, longitude: 14.0)
    @ep1 = Episode.create!(season: @season, number_in_season: 1, title: "Dunes", location: @namibia, air_date: Date.new(2024, 2, 2))
    @ep2 = Episode.create!(season: @season, number_in_season: 2, title: "Coast", location: @namibia, air_date: Date.new(2024, 2, 9))
    @future = Episode.create!(season: @season, number_in_season: 3, title: "Not Yet Aired", location: @namibia, air_date: Date.current + 30)
    s = Survivor.create!(full_name: "Region Tester")
    Appearance.create!(survivor: s, episode: @ep1)
  end

  teardown { NameSlugs.reset! }

  def title = css_select("head title").first.text
  def description = css_select('head meta[name="description"]').first["content"]
  def canonical = css_select("link[rel=canonical]").first["href"]
  def json_ld = css_select('script[type="application/ld+json"]').map { |n| JSON.parse(n.text) }.flatten

  test "the Africa hub renders from the data" do
    get "/episodes/by_region/africa"
    assert_response :success
    assert_equal "Naked and Afraid in Africa: Every Filming Location & Episode", title
    assert_select "h1", count: 1, text: "Naked and Afraid in Africa"
    assert_equal "http://www.example.com/episodes/by_region/africa", canonical
    # 3 Namibia episodes + 1 South Africa fixture episode, 2 seasons, 2 survivalists on record, 2 places.
    assert_select ".region-intro", text: /4 episodes of Naked and Afraid filmed in Africa, from 2 seasons, across 2 places, with 2 survivalists on record\./
    assert_select ".region-country-card h3 a[href=?]", "/episodes/by_country/namibia", text: "Namibia"
    assert_select ".region-country-card h3 a[href=?]", "/episodes/by_country/south-africa", text: "South Africa"
    assert_select ".region-country-card", text: /3 episodes/
  end

  test "country cards carry the first sentence of the country description" do
    get "/episodes/by_region/africa"
    lead = helper_lead("Namibia")
    assert lead.present?
    assert_select ".region-country-card", text: /#{Regexp.escape(lead)}/
  end

  def helper_lead(country)
    ApplicationController.helpers.country_description_lead(country)
  end

  test "latest episodes list only aired episodes, newest first" do
    get "/episodes/by_region/africa"
    titles = css_select("#region-recent-heading ~ .table-responsive tbody tr td:first-child a, section[aria-labelledby=region-recent-heading] tbody tr td:first-child a").map(&:text)
    assert_equal ["Test Episode B", "Coast", "Dunes"], titles.first(3) # the fixture episode aired 2025-09-11
    assert_not_includes titles, "Not Yet Aired"
  end

  test "FAQ is answered from the data, visible, and matches the FAQPage JSON-LD" do
    get "/episodes/by_region/africa"
    faq = json_ld.find { |n| n["@type"] == "FAQPage" }
    qa = faq["mainEntity"].to_h { |q| [q["name"], q["acceptedAnswer"]["text"]] }
    where = ActionController::Base.helpers.strip_tags(qa["Where in Africa was Naked and Afraid filmed?"])
    assert_equal "Our database has episodes filmed in Namibia (3 episodes), South Africa (1 episode).", where
    assert_match(%r{<a href="/episodes/by_country/namibia">Namibia</a>}, qa["Where in Africa was Naked and Afraid filmed?"])
    assert_equal "4 episodes in our database were filmed in Africa.", qa["How many Naked and Afraid episodes were filmed in Africa?"]
    assert_equal "Namibia has the most, with 3 episodes.", qa["Which place in Africa has the most Naked and Afraid episodes?"]
    qa.each_key { |q| assert_select "details summary", text: q }
  end

  test "ItemList JSON-LD lists the countries with their pages" do
    get "/episodes/by_region/africa"
    list = json_ld.find { |n| n["@type"] == "ItemList" }
    assert_equal 2, list["numberOfItems"]
    assert_equal ["Namibia", "South Africa"], list["itemListElement"].map { |i| i["name"] }
    assert_equal "http://www.example.com/episodes/by_country/namibia", list["itemListElement"].first["url"]
    assert json_ld.any? { |n| n["@type"] == "CollectionPage" }
    assert json_ld.any? { |n| n["@type"] == "BreadcrumbList" }
  end

  test "an unknown region and a region with no episodes are 404s" do
    get "/episodes/by_region/atlantis"
    assert_response :not_found
    get "/episodes/by_region/asia"   # in the config, but no Asian episodes in this database
    assert_response :not_found
    get "/episodes/by_region/europe"
    assert_response :not_found
  end

  test "case variants, aliases and the query string 301 to the slug" do
    get "/episodes/by_region/Africa"
    assert_redirected_to "/episodes/by_region/africa"
    assert_response :moved_permanently

    get "/episodes/by_region/AFRICA?utm=x"
    assert_redirected_to "/episodes/by_region/africa?utm=x"

    get "/episodes/by_region/caribbean"
    assert_response :moved_permanently
    assert_redirected_to "/episodes/by_region/central-america-caribbean"
  end

  test "titles and descriptions are unique per region, within length, and name no empty place" do
    Location.create!(country: "Belize", site: "Reef", latitude: 17.0, longitude: -88.0).then do |loc|
      Episode.create!(season: @season, number_in_season: 9, title: "Cayes", location: loc, air_date: Date.new(2024, 3, 3))
    end
    pages = %w[africa central-america-caribbean].map do |slug|
      get "/episodes/by_region/#{slug}"
      assert_response :success
      assert_operator description.length, :<=, 160
      assert_operator title.length, :<=, 70
      [title, description]
    end
    assert_equal pages.map(&:first).uniq.size, pages.size
    assert_equal pages.map(&:last).uniq.size, pages.size
    assert_match(/Belize/, pages.last.last)
    assert_no_match(/Asia|Tanzania|Zambia/, pages.first.last)
  end

  test "a long region name still gets a title that fits" do
    Episode.create!(season: @season, number_in_season: 8, title: "Reef", air_date: Date.new(2024, 3, 3),
                    location: Location.create!(country: "Belize", site: "Reef", latitude: 17.0, longitude: -88.0))
    get "/episodes/by_region/central-america-caribbean"
    assert_operator title.length, :<=, SeoHelper::MAX_TITLE_LENGTH + 20
    assert_match "Central America & Caribbean", css_select("h1").first.text
  end

  test "the region page is listed in the sitemap, empty regions are not" do
    get "/sitemap.xml"
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
    assert_includes locs, "#{HOST}/episodes/by_region/africa"
    assert_includes locs, "#{HOST}/episodes/by_region/central-america-caribbean"
    assert_not_includes locs, "#{HOST}/episodes/by_region/asia"
    lastmod = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url[loc='#{HOST}/episodes/by_region/africa']/lastmod").text
    assert_match(/\A\d{4}-\d\d-\d\dT/, lastmod)
  end

  test "/locations links to every region that has episodes and to no empty one" do
    get "/locations"
    assert_select "nav.region-strip a[href=?]", "/episodes/by_region/africa"
    assert_select "nav.region-strip a[href=?]", "/episodes/by_region/central-america-caribbean"
    assert_select "nav.region-strip a[href=?]", "/episodes/by_region/asia", 0
  end

  test "a country page links to the rest of its region" do
    get "/episodes/by_country/namibia"
    assert_select "nav.country-region-links" do
      assert_select "strong", text: "More in Africa:"
      assert_select "a[href=?]", "/episodes/by_country/south-africa"
      assert_select "a[href=?]", "/episodes/by_region/africa", text: /All of Africa/
      assert_select "a[href=?]", "/episodes/by_country/namibia", 0
    end
  end

  test "a country in no region has no region links" do
    Episode.create!(season: @season, number_in_season: 7, title: "Atlantis Ep", air_date: Date.new(2024, 4, 4),
                    location: Location.create!(country: "Atlantis", site: "Lost", latitude: 1.0, longitude: 1.0))
    get "/episodes/by_country/atlantis"
    assert_response :success
    assert_select "nav.country-region-links", 0
  end

  test "pagination is not a thing here: ?page=2 keeps the same canonical" do
    get "/episodes/by_region/africa?page=2"
    assert_equal "http://www.example.com/episodes/by_region/africa", canonical
  end
end
