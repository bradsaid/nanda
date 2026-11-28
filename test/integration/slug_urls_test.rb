require "test_helper"

# Hyphenated slug URLs for episodes, items, countries, food sources, shelter types and item
# types: the slug URL is the one page, every other spelling 301s to it, and nothing the app
# links to or lists is a numeric or spaced URL.
class SlugUrlsTest < ActionDispatch::IntegrationTest
  HOST = "https://www.nakedandafraidfan.com".freeze

  setup do
    @series  = Series.create!(name: "Naked and Afraid")
    @season  = Season.create!(series: @series, number: 14, year: 2024)
    @africa  = Location.create!(country: "South Africa", site: "Slug Camp", latitude: -30.0, longitude: 25.0)
    @episode = Episode.create!(season: @season, number_in_season: 2, title: "Haunted and Hungry", location: @africa,
                               air_date: Date.new(2024, 3, 3))
    @item    = Item.create!(name: "fire starter")
    @survivor = Survivor.create!(full_name: "Slug Survivor")
    @appearance = Appearance.create!(survivor: @survivor, episode: @episode)
    AppearanceItem.create!(appearance: @appearance, item: @item, source: "brought")
    Rails.cache.clear
  end

  def canonical = css_select("link[rel=canonical]").first["href"]
  def og_url    = css_select('meta[property="og:url"]').first["content"]

  # Every string in the page's JSON-LD that is a URL or a site path.
  def json_ld_urls
    walk = lambda do |node|
      case node
      when Hash  then node.values.flat_map(&walk)
      when Array then node.flat_map(&walk)
      when String then node.start_with?("http", "/") ? [node] : []
      else []
      end
    end
    css_select('script[type="application/ld+json"]').flat_map { |s| walk.call(JSON.parse(s.text)) }
  end

  # ---------- episodes ----------

  test "episode slug is series + season + number + title" do
    assert_equal "naked-and-afraid-s14e2-haunted-and-hungry", @episode.slug
    assert_equal "/episodes/naked-and-afraid-s14e2-haunted-and-hungry", episode_path(@episode)
  end

  test "the slug URL is a 200 with the slug URL as canonical and og:url" do
    get "/episodes/naked-and-afraid-s14e2-haunted-and-hungry"
    assert_response :success
    assert_equal "http://www.example.com/episodes/naked-and-afraid-s14e2-haunted-and-hungry", canonical
    assert_equal canonical, og_url
  end

  test "the numeric id 301s to the slug URL and keeps the query string" do
    get "/episodes/#{@episode.id}"
    assert_response :moved_permanently
    assert_redirected_to "/episodes/naked-and-afraid-s14e2-haunted-and-hungry"

    get "/episodes/#{@episode.id}", params: { utm_source: "x", a: "b" }
    assert_response :moved_permanently
    assert_equal "http://www.example.com/episodes/naked-and-afraid-s14e2-haunted-and-hungry?utm_source=x&a=b", response.location
  end

  test "an old slug 301s to the current one; a slug in capitals 301s to the lower-case URL" do
    @episode.update!(slug: "naked-and-afraid-s14e2-new-slug")
    get "/episodes/naked-and-afraid-s14e2-haunted-and-hungry"
    assert_redirected_to "/episodes/naked-and-afraid-s14e2-new-slug"
    get "/episodes/Naked-And-Afraid-S14E2-New-Slug"
    assert_redirected_to "/episodes/naked-and-afraid-s14e2-new-slug"
    get "/episodes/naked-and-afraid-s14e2-new-slug"
    assert_response :success
  end

  test "an unknown episode is a 404, whether it looks like a slug or an id" do
    get "/episodes/no-such-episode"
    assert_response :not_found
    get "/episodes/999999999"
    assert_response :not_found
  end

  test "a numeric-id redirect is not recorded as a page view, the slug page is" do
    ua = "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/120 Safari/537.36"
    assert_no_difference "PageView.count" do
      get "/episodes/#{@episode.id}", headers: { "User-Agent" => ua }
    end
    assert_difference "PageView.count", 1 do
      get "/episodes/naked-and-afraid-s14e2-haunted-and-hungry", headers: { "User-Agent" => ua }
    end
    assert_equal "/episodes/naked-and-afraid-s14e2-haunted-and-hungry", PageView.order(:id).last.path
  end

  test "an episode with no slug yet (half-migrated) is reachable by id and links by id, never a 500" do
    @episode.update_columns(slug: nil)
    assert_equal "/episodes/#{@episode.id}", episode_path(@episode.reload)
    get "/episodes/#{@episode.id}"
    assert_response :success
    get "/episodes"
    assert_response :success
    get "/sitemap.xml"
    assert_response :success
  end

  # ---------- items ----------

  test "item pages: slug 200 + canonical, numeric id and old slug 301, unknown 404" do
    get "/items/fire-starter"
    assert_response :success
    assert_equal "http://www.example.com/items/fire-starter", canonical
    assert_equal canonical, og_url

    get "/items/#{@item.id}", params: { country: "South Africa" }
    assert_response :moved_permanently
    assert_equal "http://www.example.com/items/fire-starter?country=South+Africa", response.location

    @item.update!(name: "ferro rod")
    get "/items/fire-starter"
    assert_redirected_to "/items/ferro-rod"
    get "/items/ferro-rod"
    assert_response :success

    get "/items/not-an-item"
    assert_response :not_found
  end

  # ---------- countries ----------

  test "country page lives at the hyphenated slug" do
    get "/episodes/by_country/south-africa"
    assert_response :success
    assert_equal "http://www.example.com/episodes/by_country/south-africa", canonical
    assert_select "h1", text: /South Africa/
    assert_select "a[href=?]", episode_path(@episode)
  end

  test "old country URLs (spaces, %20, plus, any case) 301 to the slug and keep the query string" do
    ["/episodes/by_country/South%20Africa", "/episodes/by_country/south%20africa", "/episodes/by_country/SOUTH+AFRICA",
     "/episodes/by_country/South-Africa", "/episodes/by_country/south_africa"].each do |old|
      get old
      assert_response :moved_permanently, old
      assert_equal "http://www.example.com/episodes/by_country/south-africa", response.location, old
    end
    get "/episodes/by_country/South%20Africa?page=2"
    assert_equal "http://www.example.com/episodes/by_country/south-africa?page=2", response.location
  end

  test "an unknown country is a 404" do
    get "/episodes/by_country/atlantis"
    assert_response :not_found
    get "/episodes/by_country/south-africa-2"
    assert_response :not_found
  end

  test "?country= still redirects to the slug country page" do
    get episodes_path(country: "South Africa")
    assert_response :moved_permanently
    assert_redirected_to "/episodes/by_country/south-africa"
  end

  test "countries with dots, accents, ampersands, apostrophes and US states work, old URL included" do
    {
      "St. Lucia" => "st-lucia", "Côte d'Ivoire" => "cote-d-ivoire",
      "Bosnia & Herzegovina" => "bosnia-herzegovina", "Louisiana" => "louisiana"
    }.each do |name, slug|
      loc = Location.create!(country: name, site: "Tricky #{slug}", latitude: 1.0, longitude: 1.0)
      Episode.create!(season: @season, number_in_season: 20 + slug.size, title: "Tricky #{slug}", location: loc)
      NameSlugs.reset!

      get "/episodes/by_country/#{slug}"
      assert_response :success, name
      assert_select "h1", text: /#{Regexp.escape(name)}/

      get "/episodes/by_country/#{ERB::Util.url_encode(name)}"   # the old spaced / dotted / accented URL
      assert_response :moved_permanently, name
      assert_redirected_to "/episodes/by_country/#{slug}"
    end
  end

  test "the app's own country links are slug URLs" do
    get episode_path(@episode)
    assert_select "a[href='/episodes/by_country/south-africa']"
    get locations_path
    assert_select "a[href='/episodes/by_country/south-africa']"
    get survivor_path(@survivor)
    assert_select "a[href='/episodes/by_country/south-africa']"
    get root_path
    assert_select "a[href^='/episodes/by_country/']" do |links|
      assert(links.all? { |a| a["href"] =~ %r{\A/episodes/by_country/[a-z0-9-]+\z} })
    end
  end

  # ---------- food sources, shelters, item types ----------

  test "food source: slug round trip, old spaced URL 301, dotted name, unknown 404" do
    FoodSource.create!(episode: @episode, name: "angel fish", category: "animal")
    FoodSource.create!(episode: @episode, name: "st. john's wort", category: "plant")

    get "/food_sources/angel-fish"
    assert_response :success
    assert_select "h1", text: /Angel Fish/

    get "/food_sources/angel%20fish"
    assert_redirected_to "/food_sources/angel-fish"
    get "/food_sources/Angel%20Fish"
    assert_redirected_to "/food_sources/angel-fish"

    get "/food_sources/st.%20john's%20wort"
    assert_redirected_to "/food_sources/st-john-s-wort"
    get "/food_sources/st-john-s-wort"
    assert_response :success

    get "/food_sources/unobtainium"
    assert_response :not_found

    get "/food_sources"
    assert_select "a[href='/food_sources/angel-fish']"
    assert_select "a[href*='%20']", false
  end

  test "shelter type: slug round trip, old URL 301, unknown 404" do
    EpisodeShelter.create!(episode: @episode, shelter_type: "A-Frame (debris)", materials: "sticks")
    get "/shelters/a-frame-debris"
    assert_response :success
    assert_select "h1", text: "A-Frame (debris)"

    get "/shelters/A-Frame%20(debris)"
    assert_redirected_to "/shelters/a-frame-debris"
    get "/shelters/nothing-here"
    assert_response :not_found

    get "/shelters"
    assert_select "a[href='/shelters/a-frame-debris']"
    get episode_path(@episode)
    assert_select "a[href='/shelters/a-frame-debris']"
  end

  test "colliding shelter names get distinct, resolvable slugs" do
    EpisodeShelter.create!(episode: @episode, shelter_type: "Lean-to")
    EpisodeShelter.create!(episode: @episode, shelter_type: "lean to")
    get "/shelters/lean-to"
    assert_response :success
    get "/shelters/lean-to-2"
    assert_response :success
    assert_equal({ "Lean-to" => "lean-to", "lean to" => "lean-to-2" }, NameSlugs.all(:shelter).to_h)   # capitals sort first
    get "/shelters/lean%20to"   # the old URL of the second one finds the second one
    assert_redirected_to "/shelters/lean-to-2"
  end

  test "item type pages: hyphenated slug, old spaced URL 301" do
    assert_equal "fire starting tool", @item.item_type
    get "/items/types/fire-starting-tool"
    assert_response :success
    get "/items/types/fire%20starting%20tool"
    assert_redirected_to "/items/types/fire-starting-tool"
    get "/items/types/no-such-type"
    assert_response :not_found
    get "/items"
    assert_select "a[href='/items/types/fire-starting-tool']"
  end

  # ---------- no numeric / spaced URLs leak into pages ----------

  test "pages that list episodes, items and names link to slug URLs only" do
    FoodSource.create!(episode: @episode, name: "angel fish", category: "animal")
    EpisodeShelter.create!(episode: @episode, shelter_type: "Lean-to")
    pages = ["/", "/episodes", "/items", "/seasons", season_path(@season), "/survivors", survivor_path(@survivor),
             episode_path(@episode), item_path(@item), "/episodes/by_country/south-africa", "/locations",
             "/food_sources", "/food_sources/angel-fish", "/shelters", "/shelters/lean-to",
             "/items/types/fire-starting-tool", "/series", series_path(@series)]
    pages.each do |page|
      get page
      assert_response :success, page
      hrefs = css_select("a[href]").map { |a| a["href"] }
      leaked = hrefs.grep(%r{\A/(episodes|items)/\d+(\z|[?#])}) + hrefs.grep(%r{\A/(episodes/by_country|food_sources|shelters|items/types)/[^?#]*(%20|\+| )})
      assert_empty leaked, "#{page} links to old-style URLs: #{leaked.inspect}"
    end
  end

  test "the survivor page links the items they brought by slug, not by id" do
    get survivor_path(@survivor)
    assert_select "a[href='/items/fire-starter']"
    assert_select "a[href='/items/#{@item.id}']", false
  end

  test "old numeric links stored inside survivor bios are rewritten to slug URLs when rendered" do
    @survivor.update!(bio: %(Appeared on <a href="/episodes/#{@episode.id}">the episode</a> in <a href="/episodes/by_country/South%20Africa">South Africa</a>.))
    get survivor_path(@survivor)
    assert_select "p.survivor-bio a[href='/episodes/naked-and-afraid-s14e2-haunted-and-hungry']"
    assert_select "p.survivor-bio a[href='/episodes/by_country/south-africa']"
    assert_select "p.survivor-bio a[href='/episodes/#{@episode.id}']", false
  end

  # ---------- structured data ----------

  test "JSON-LD urls use the slug URLs" do
    [episode_path(@episode), item_path(@item), "/episodes/by_country/south-africa", "/episodes", "/items", survivor_path(@survivor)].each do |page|
      get page
      assert_response :success, page
      urls = json_ld_urls
      assert_empty urls.grep(%r{/(episodes|items)/\d+(\b|\z)}), "#{page} JSON-LD has numeric URLs: #{urls.grep(%r{/(episodes|items)/\d+}).inspect}"
      assert_empty urls.grep(%r{by_country/[^"\s]*(%20|\+| |[A-Z])}), page
    end
    get episode_path(@episode)
    assert_includes css_select('script[type="application/ld+json"]').map(&:text).join, "/episodes/naked-and-afraid-s14e2-haunted-and-hungry"
  end

  # ---------- sitemap ----------

  test "the sitemap lists slug URLs and no numeric episode or item URL, no spaced name URL" do
    FoodSource.create!(episode: @episode, name: "angel fish", category: "animal")
    EpisodeShelter.create!(episode: @episode, shelter_type: "Lean-to")
    # Thin pages are not listed (ThinContent): give the episode a synopsis, and let food and
    # shelter pages with a single episode count.
    @episode.update_columns(synopsis: "Two survivalists land in the jungle.")
    old_env = %w[THIN_FOOD_SOURCE_MIN_EPISODES THIN_SHELTER_MIN_EPISODES].to_h { |k| [ k, ENV[k] ] }
    old_env.each_key { |k| ENV[k] = "0" }
    get "/sitemap.xml"
    old_env.each { |k, v| ENV[k] = v }
    assert_response :success
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)

    assert_includes locs, "#{HOST}/episodes/naked-and-afraid-s14e2-haunted-and-hungry"
    assert_includes locs, "#{HOST}/items/fire-starter"
    assert_includes locs, "#{HOST}/episodes/by_country/south-africa"
    assert_includes locs, "#{HOST}/food_sources/angel-fish"
    assert_includes locs, "#{HOST}/shelters/lean-to"
    assert_includes locs, "#{HOST}/items/types/fire-starting-tool"
    assert_empty locs.grep(%r{/(episodes|items)/\d+\z})
    assert_empty locs.grep(/%20|\+| /)
    assert_equal locs.uniq, locs
  end

  test "the sitemap cache key is versioned past the numeric-URL sitemap" do
    assert_operator SitemapUrls::VERSION, :>=, 3
  end

  # ---------- admin ----------

  test "admin edit, update and delete work with the slug as the episode's param" do
    admin = users(:admin)
    post session_path, params: { email_address: admin.email_address, password: "password" }

    assert_equal "/admin/episodes/naked-and-afraid-s14e2-haunted-and-hungry/edit", edit_admin_episode_path(@episode)
    get edit_admin_episode_path(@episode)
    assert_response :success
    assert_select "form[action=?]", admin_episode_path(@episode)

    patch admin_episode_path(@episode), params: { episode: { notes: "changed", title: "Haunted and Hungry (Extended)" } }
    assert_redirected_to admin_episodes_path
    @episode.reload
    assert_equal "changed", @episode.notes
    assert_equal "naked-and-afraid-s14e2-haunted-and-hungry", @episode.slug, "the public URL does not move when the title is edited"

    get edit_admin_episode_path(@episode.id)   # a numeric id still resolves in admin
    assert_response :success

    delete admin_episode_path(@episode)
    assert_redirected_to admin_episodes_path
    assert_nil Episode.find_by(id: @episode.id)
  end

  test "an episode created in the admin form gets its slug" do
    admin = users(:admin)
    post session_path, params: { email_address: admin.email_address, password: "password" }
    assert_difference "Episode.count", 1 do
      post admin_episodes_path, params: { episode: {
        season_id: @season.id, number_in_season: 7, title: "Brand New One", location_id: @africa.id,
        appearances_attributes: { "0" => { survivor_id: @survivor.id, role: "solo" } }
      } }
    end
    created = Episode.find_by!(title: "Brand New One")
    assert_equal "naked-and-afraid-s14e7-brand-new-one", created.slug
    assert_redirected_to "/admin/episodes/naked-and-afraid-s14e7-brand-new-one/edit"
    follow_redirect!
    assert_response :success
  end

  test "admin traffic counts views recorded under the slug URL and the old numeric URL" do
    admin = users(:admin)
    post session_path, params: { email_address: admin.email_address, password: "password" }
    2.times { PageView.create!(path: "/episodes/#{@episode.id}", controller_name: "episodes", action_name: "show", method: "GET") }
    3.times { PageView.create!(path: "/episodes/#{@episode.slug}", controller_name: "episodes", action_name: "show", method: "GET") }
    Rails.cache.clear
    get admin_episodes_path(sort: "traffic")
    assert_response :success
    assert_select "td.text-end.small", text: "5"
  end
end
