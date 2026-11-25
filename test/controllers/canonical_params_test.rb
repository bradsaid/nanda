require "test_helper"

# Canonical and og:url must point at the clean URL whenever the page ignores a query
# parameter, so ?page=2, ?sort=, ?q= and tracking junk never mint their own canonical.
class CanonicalParamsTest < ActionDispatch::IntegrationTest
  def canonical = css_select("link[rel=canonical]").first["href"]
  def og_url    = css_select('meta[property="og:url"]').first["content"]

  # Public pages with no real pagination: ?page= is ignored, so it must be dropped.
  UNPAGINATED = [
    -> { episode_path(episodes(:one)) },
    -> { survivor_path(survivors(:one)) },
    -> { item_path(items(:one)) },
    -> { season_path(seasons(:one)) },
    -> { series_path(series(:one)) },
    -> { "/items" },
    -> { "/seasons" },
    -> { "/series" },
    -> { "/locations" },
    -> { "/shop" },
    -> { "/shop/guides" },
    -> { "/food_sources" },
    -> { "/shelters" },
    -> { "/about" },
    -> { "/privacy_policy" },
    -> { "/terms_of_service" },
    -> { "/contact" },
    -> { "/forum/guidelines" }
  ].freeze

  # Paginated lists: only ?page=N (N > 1) may appear, see the pagination tests.
  # Here, other params must still be dropped.
  PAGINATED = [-> { "/survivors" }, -> { "/episodes" }].freeze

  test "pages without pagination canonicalise to the clean URL whatever ?page, ?sort, ?q or tracking params say" do
    UNPAGINATED.each do |path_proc|
      path = instance_exec(&path_proc)
      get path, params: { page: 2, sort: "name", q: "zz", utm_source: "newsletter", foo: "bar" }
      next unless response.successful?
      assert_equal "http://www.example.com#{path}", canonical, "canonical for #{path}"
      assert_equal canonical, og_url, "og:url for #{path}"
    end
  end

  test "paginated lists drop sort, q and tracking params from the canonical" do
    PAGINATED.each do |path_proc|
      path = instance_exec(&path_proc)
      get path, params: { sort: "newest", q: "zz", utm_source: "x" }
      assert_response :success
      assert_equal "http://www.example.com#{path}", canonical
      assert_equal canonical, og_url
    end
  end

  test "the homepage ignores query params too" do
    get root_path, params: { page: 2, utm_source: "x" }
    assert_equal "http://www.example.com/", canonical
    assert_equal "http://www.example.com/", og_url
  end

  test "the country page canonicalises to its own clean path" do
    country = locations(:one).country
    skip "fixture location has no country" if country.blank?
    path = by_country_episodes_path(country: NameSlugs.slug(:country, country))
    get path, params: { sort: "x", foo: "bar" }
    assert_response :success
    assert_equal "http://www.example.com#{path}", canonical
  end

  test "params that select different content are kept, in a stable order" do
    get episodes_path, params: { location_id: locations(:one).id, sort: "airdate", page: 3 }
    assert_equal "http://www.example.com/episodes?location_id=#{locations(:one).id}", canonical

    get items_path, params: { source: "given", country: "Peru", q: "x", limit: 50 }
    assert_equal "http://www.example.com/items?country=Peru&source=given", canonical
  end

  test "searching sends noindex,follow on internal search results only" do
    ["/survivors", "/items", "/locations"].each do |path|
      get path, params: { q: "zz" }
      assert_response :success
      assert_select "meta[name=robots][content=?]", "noindex, follow", true, "#{path}?q= should be noindex,follow"
      get path
      assert_select "meta[name=robots]", false, "#{path} itself must stay indexable"
    end
  end
end
