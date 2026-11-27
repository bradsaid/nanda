require "test_helper"

# Misspellings / alternate names of filming countries (config/country_aliases.yml): 301 to the
# real country page, a visible "also spelled" line, aliases in the meta description when they
# fit, and the Locations search.
class CountryAliasesTest < ActionDispatch::IntegrationTest
  setup do
    NameSlugs.reset!
    CountryAliases.reset!
    @series = Series.create!(name: "Alias Test Series")
    @season = Season.create!(series: @series, number: 1, year: 2024)
    @colombia = Location.create!(country: "Colombia", site: "Jungle", latitude: 4.0, longitude: -74.0)
    @ph = Location.create!(country: "Philippines", site: "Island", latitude: 12.0, longitude: 121.0)
    Episode.create!(season: @season, number_in_season: 1, title: "Colombian Jungle", location: @colombia, air_date: Date.new(2024, 1, 1))
    Episode.create!(season: @season, number_in_season: 2, title: "Island Ep", location: @ph, air_date: Date.new(2024, 1, 8))
  end

  teardown { NameSlugs.reset!; CountryAliases.reset! }

  def description = css_select('head meta[name="description"]').first["content"]

  # ---- lookups ----

  test "aliases resolve to their canonical country in any spelling" do
    assert_equal "Colombia", CountryAliases.canonical_for("columbia")
    assert_equal "Colombia", CountryAliases.canonical_for("Columbia")
    assert_equal "Philippines", CountryAliases.canonical_for("phillipines")
    assert_equal "Philippines", CountryAliases.canonical_for("Philipines")
    assert_equal "Mexico", CountryAliases.canonical_for("México")
    assert_equal ["Columbia"], CountryAliases.for("colombia")
    assert_equal [], CountryAliases.for("Peru")
    assert_nil CountryAliases.canonical_for("atlantis")
    assert_nil CountryAliases.canonical_for("")
  end

  test "two countries can share an alias (Trinidad and Tobago)" do
    assert_equal %w[Trinidad Tobago], CountryAliases.canonicals_for("trinidad-and-tobago")
  end

  test "no alias collides with a different canonical country's own name" do
    canonical = CountryAliases.send(:raw).keys.map { |k| k.parameterize }
    CountryAliases.send(:raw).each do |country, aliases|
      aliases.each do |a|
        assert_not_includes canonical - [country.parameterize], a.parameterize, "#{a} (alias of #{country}) is another country's name"
      end
    end
  end

  test "NameSlugs resolves an alias to the canonical match, a real country first, an unknown not at all" do
    match = NameSlugs.resolve(:country, "columbia")
    assert_equal "colombia", match.slug
    assert_equal "Colombia", match.name

    Location.create!(country: "Columbia", site: "A real place called this", latitude: 1.0, longitude: 1.0)
    NameSlugs.reset!
    assert_equal "columbia", NameSlugs.resolve(:country, "columbia").slug # a real country wins over the alias

    assert_nil NameSlugs.resolve(:country, "atlantis")
  end

  test "an alias for a country with no episodes in the data is not found" do
    assert_nil NameSlugs.resolve(:country, "brasil") # no Brazil location in this database
    assert_nil NameSlugs.resolve(:food_source, "columbia") # only countries have aliases
  end

  # ---- redirects ----

  test "/episodes/by_country/columbia 301s to colombia and keeps the query string" do
    get "/episodes/by_country/columbia"
    assert_response :moved_permanently
    assert_redirected_to "/episodes/by_country/colombia"

    get "/episodes/by_country/Columbia?page=1"
    assert_response :moved_permanently
    assert_redirected_to "/episodes/by_country/colombia?page=1"
  end

  test "the misspelled Philippines URLs 301 to the canonical page" do
    %w[phillipines philipines phillippines Phillipines].each do |segment|
      get "/episodes/by_country/#{segment}"
      assert_response :moved_permanently, segment
      assert_redirected_to "/episodes/by_country/philippines"
    end
  end

  test "/episodes?country=Columbia ends up on the canonical page" do
    get "/episodes", params: { country: "Columbia" }
    assert_response :moved_permanently
    follow_redirect!
    assert_response :moved_permanently
    assert_redirected_to "/episodes/by_country/colombia"
    follow_redirect!
    assert_response :success
  end

  test "an unknown name is still a 404" do
    get "/episodes/by_country/narnia"
    assert_response :not_found
    get "/episodes/by_country/columbiaa"
    assert_response :not_found
  end

  test "a redirect is not recorded as a page view" do
    assert_no_difference "PageView.count" do
      get "/episodes/by_country/columbia", headers: { "User-Agent" => "Mozilla/5.0 (Macintosh) Safari/605" }
    end
  end

  # ---- the country page ----

  test "the country page shows the aliases and works them into the description" do
    get "/episodes/by_country/colombia"
    assert_response :success
    assert_select "p.country-aliases", text: "Also spelled or known as: Columbia"
    assert_equal "All 1 episode(s) filmed in Colombia (also searched as Columbia): air dates, locations, and survivors.", description
    assert_operator description.length, :<=, 160
  end

  test "several aliases are all named when they fit, else the first, else none" do
    get "/episodes/by_country/philippines"
    assert_select "p.country-aliases", text: "Also spelled or known as: Phillipines, Philipines, Phillippines"
    assert_match "also searched as Phillipines, Philipines, or Phillippines", description
    assert_operator description.length, :<=, 160
  end

  test "country_meta_description falls back so it never exceeds 160 characters" do
    helper = ApplicationController.helpers
    long_aliases = ["An Extremely Long Alternate Name For This Place " * 2, "Another Very Long Alternate Name"]
    text = helper.country_meta_description("Colombia", 12, long_aliases)
    assert_operator text.length, :<=, 160
    assert_equal "All 12 episode(s) filmed in Colombia: air dates, locations, and survivors.", text
    assert_equal "All 12 episode(s) filmed in Colombia: air dates, locations, and survivors.", helper.country_meta_description("Colombia", 12, [])
    assert_match "(page 2)", helper.country_meta_description("Colombia", 12, ["Columbia"], 2)
  end

  test "a country without aliases is unchanged" do
    Episode.create!(season: @season, number_in_season: 3, title: "Peru Ep", air_date: Date.new(2024, 2, 2),
                    location: Location.create!(country: "Peru", site: "Andes", latitude: -10.0, longitude: -75.0))
    get "/episodes/by_country/peru"
    assert_select "p.country-aliases", 0
    assert_equal "All 1 episode(s) filmed in Peru: air dates, locations, and survivors.", description
  end

  # ---- Locations search ----

  test "the Locations search matches aliases and says why" do
    get "/locations", params: { q: "columbia" }
    assert_response :success
    assert_select ".country-card .fw-semibold", text: "Colombia"
    assert_select ".country-alias-hint", text: "also spelled Columbia"
    assert_select ".country-card .fw-semibold", text: "Philippines", count: 0

    get "/locations", params: { q: "phillip" }
    assert_select ".country-card .fw-semibold", text: "Philippines"
  end

  test "a search by the real name has no alias hint" do
    get "/locations", params: { q: "colom" }
    assert_select ".country-card .fw-semibold", text: "Colombia"
    assert_select ".country-alias-hint", 0
  end
end
