require "test_helper"

# <title>, meta description and headings: unique, accurate, within length, one h1.
class SeoTitlesAndDescriptionsTest < ActionDispatch::IntegrationTest
  def title = css_select("head title").first.text
  def description = css_select('head meta[name="description"]').first["content"]
  def h1s = css_select("h1")

  setup do
    ENV["FORUM_ENABLED"] = nil
    create_podcast_survivors
  end

  # /podcasts looks survivors up by name and links to them; give it the ones it names.
  def create_podcast_survivors
    File.read(Rails.root.join("app/views/static_pages/podcasts.html.slim")).scan(/find_by\(full_name: "([^"]+)"\)/).flatten.uniq.each do |name|
      Survivor.find_or_create_by!(full_name: name)
    end
  end

  # ---------- helper unit tests ----------

  class Helper
    include ActionView::Helpers::TextHelper
    include SeoHelper
  end

  def helper = @helper ||= Helper.new

  test "site_title adds the site name once and never doubles it" do
    assert_equal "Privacy Policy — Naked & Afraid Fan Wiki", helper.site_title("Privacy Policy")
    assert_equal "Naked & Afraid Fan Wiki", helper.site_title("Naked & Afraid Fan Wiki")
    assert_equal "Forum — Naked and Afraid Fan Wiki", helper.site_title("Forum — Naked and Afraid Fan Wiki")
    assert_equal "Naked and Afraid — Naked & Afraid Fan Database", helper.site_title("Naked and Afraid — Naked & Afraid Fan Database")
    assert_equal "Naked & Afraid Fan Wiki", helper.site_title("")
  end

  test "site_title leaves a title alone when the suffix would make it too long" do
    long = "Naked and Afraid Last One Standing — Seasons, Episodes & Cast"
    assert_equal long, helper.site_title(long)
    assert_operator helper.site_title("Short").length, :<=, SeoHelper::MAX_TITLE_LENGTH
  end

  test "page titles and descriptions only change after page one" do
    assert_equal "Survivors", helper.paginated_title("Survivors", 1)
    assert_equal "Survivors", helper.paginated_title("Survivors", nil)
    assert_equal "Survivors — Page 3", helper.paginated_title("Survivors", 3)
    assert_equal "About survivors.", helper.paginated_description("About survivors.", 1)
    assert_equal "About survivors. (page 2)", helper.paginated_description("About survivors.", 2)
    long = "word " * 60
    assert_operator helper.paginated_description(long, 12).length, :<=, 160
    assert helper.paginated_description(long, 12).end_with?("… (page 12)")
  end

  test "meta_excerpt strips markup, entities, emails and cuts at a word boundary" do
    html = "<p>Hello &amp; welcome,  <b>friends</b>!</p>\n<p>Write to me@example.com or visit us.</p>"
    assert_equal "Hello & welcome, friends! Write to or visit us.", helper.meta_excerpt(html)
    text = ("lorem ipsum dolor sit amet " * 20)
    out = helper.meta_excerpt(text)
    assert_operator out.length, :<=, 150
    assert out.end_with?("…")
    # cut at a word boundary: the last word before the ellipsis is a whole word of the source
    assert_includes %w[lorem ipsum dolor sit amet], out.delete_suffix("…").split.last
    assert_equal "short", helper.meta_excerpt("short")
  end

  # ---------- static pages ----------

  test "privacy policy and terms have their own titles and descriptions, and valid nested HTML" do
    get privacy_policy_path
    assert_response :success
    privacy_title, privacy_desc = title, description
    assert_equal "Privacy Policy — Naked & Afraid Fan Wiki", privacy_title
    # One document: the policy no longer carries its own doctype/html/head/body.
    assert_equal 1, response.body.scan(/<!doctype/i).size
    assert_equal 1, response.body.scan(/<html\b/i).size
    assert_equal 1, response.body.scan(/<head\b/i).size
    assert_equal 1, response.body.scan(/<body\b/i).size
    assert_equal 1, response.body.scan(/<title\b/i).size
    assert_equal 1, response.body.scan(/<meta charset/i).size
    assert_equal 1, h1s.size
    assert_equal "en", css_select("html").first["lang"]
    assert_select "section#forum-accounts"
    assert_select "#affiliate-links"

    get terms_of_service_path
    assert_response :success
    assert_equal "Terms of Service — Naked & Afraid Fan Wiki", title
    assert_equal 1, response.body.scan(/<html\b/i).size
    assert_equal 1, response.body.scan(/<body\b/i).size
    assert_equal 1, response.body.scan(/<title\b/i).size
    assert_equal 1, h1s.size
    assert_not_equal privacy_desc, description
  end

  test "locations, privacy, terms, about and the shop each have a different title" do
    titles = [ locations_path, privacy_policy_path, terms_of_service_path, about_path, shop_path, forum_guidelines_path ].map do |path|
      get path
      assert_response :success, path
      title
    end
    assert_equal titles.uniq.size, titles.size, "titles must be unique: #{titles.inspect}"
  end

  test "/locations has a descriptive title and a description" do
    get locations_path
    assert_equal "Naked and Afraid Filming Locations by Country", title
    assert_operator description.length, :<=, 160
    assert_match(/filmed/i, description)
    assert_not_equal "Fan wiki with survivors, episodes, items, and filming locations for Naked & Afraid.", description
  end

  test "/shop description is at most 160 characters and still discloses the affiliate relationship" do
    get shop_path
    assert_operator description.length, :<=, 160
    assert_match(/affiliate/i, description)
    assert_match(/earn/i, description)
    assert_select ".shop-disclosure", /Amazon Associate/ # the visible disclosure stays
  end

  test "/podcasts has exactly one h1 and keeps its section headings as h2" do
    get "/podcasts"
    assert_response :success
    assert_equal 1, h1s.size
    assert_equal "Naked & Afraid Podcasts", h1s.first.text.strip
    assert_includes css_select("h2").map { |h| h.text.strip }, "Books by Ky Furneaux"
  end

  test "every public page has exactly one h1" do
    series = Series.create!(name: "H1 XL")
    season = Season.create!(series: series, number: 1, year: 2020)
    ep = Episode.create!(season: season, number_in_season: 1, title: "H1 Ep", air_date: Date.new(2020, 1, 1), location: locations(:one))
    item = Item.create!(name: "H1 Knife", item_type: "blade")
    paths = [ "/", "/survivors", "/survivors/#{survivors(:one).to_param}", "/episodes", "/episodes/#{ep.to_param}",
              "/episodes/by_country/#{ERB::Util.url_encode(locations(:one).country.to_s.presence || 'Nowhere')}", "/items", "/items/#{item.to_param}",
              "/series", "/series/#{series.id}", "/seasons", "/seasons/#{season.to_param}", "/locations", "/shop", "/podcasts",
              "/about", "/contact", "/privacy_policy", "/terms_of_service", "/forum/guidelines" ]
    paths.each do |path|
      get path
      follow_redirect! while response.redirect?
      next if response.status == 404 # a path whose fixture data does not exist in this DB
      assert_response :success, path
      assert_equal 1, h1s.size, "#{path} has #{h1s.size} h1 elements"
    end
  end

  # ---------- series ----------

  test "series titles are not redundant and use the series name" do
    Series.all.each do |s|
      get series_path(s)
      assert_response :success
      assert title.start_with?("#{s.name} — Seasons, Episodes & Cast"), title
      assert_operator title.scan("Fan Wiki").size, :<=, 1
      assert_operator title.length, :<=, 65
    end
    xl = Series.create!(name: "Naked and Afraid XL")
    get series_path(xl)
    assert_equal "Naked and Afraid XL — Seasons, Episodes & Cast", title
    assert_operator title.length, :<=, 65
    assert_equal 1, title.scan("Naked and Afraid").size
  end

  # ---------- /episodes ----------

  test "/episodes h1 matches its title" do
    get episodes_path
    assert_response :success
    assert_equal title, h1s.first.text.strip
    assert_equal "Naked and Afraid Episodes – By Season", title
  end

  # ---------- pagination ----------

  test "paginated lists append the page number to title and description, page one unchanged" do
    (1..(SurvivorsController::PER_PAGE + 5)).each { |i| Survivor.create!(full_name: format("Titles %03d Person", i)) }
    Rails.cache.clear
    get survivors_path
    page1_title, page1_desc, page1_h1 = title, description, h1s.first.text
    assert_equal "Naked and Afraid Survivors", page1_title
    assert_no_match(/\(page/, page1_desc)

    get survivors_path(page: 2)
    assert_equal "Naked and Afraid Survivors — Page 2", title
    assert_equal "#{page1_desc} (page 2)", description
    assert_equal page1_h1, h1s.first.text
    assert_operator description.length, :<=, 160
  end

  test "episodes and by_country pages are paginated in title and description too" do
    series = Series.create!(name: "Paged Titles XL")
    loc = Location.create!(country: "Titleland", region: "R", site: "S", latitude: 1.5, longitude: 2.5)
    (1..(EpisodesController::COUNTRY_BLOCKS_PER_PAGE + 2)).each do |n|
      season = Season.create!(series: series, number: n, year: 1990 + n)
      Episode.create!(season: season, number_in_season: 1, title: "T #{n}", air_date: Date.new(1990 + n, 1, 1), location: loc)
    end
    get by_country_episodes_path(country: "Titleland")
    follow_redirect! while response.redirect?
    assert_equal "Naked and Afraid Episodes in Titleland", title
    get by_country_episodes_path(country: "Titleland", page: 2)
    follow_redirect! while response.redirect?
    assert_equal "Naked and Afraid Episodes in Titleland — Page 2", title
    assert_match(/\(page 2\)\z/, description)

    get episodes_path(page: 2)
    assert_equal "Naked and Afraid Episodes – By Season — Page 2", title
    assert_match(/\(page 2\)\z/, description)
  end
end
