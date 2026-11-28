require "test_helper"

# Food source and shelter pages: data-driven facts, and noindex + sitemap exclusion below the
# ThinContent threshold (default: fewer than 2 linked episodes).
class ThinFactPagesTest < ActionDispatch::IntegrationTest
  HOST = "https://www.nakedandafraidfan.com".freeze

  def robots_meta = css_select('head meta[name="robots"]').first&.[]("content")
  def description = css_select('head meta[name="description"]').first["content"]

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @series = Series.create!(name: "Naked and Afraid")
    @season = Season.create!(series: @series, number: 5, year: 2015)
    @cr = Location.create!(country: "Costa Rica", region: "Guanacaste", site: "Beach", latitude: 10.0, longitude: -85.0)
    @za = Location.create!(country: "South Africa", region: "Limpopo", site: "Bush", latitude: -23.0, longitude: 30.0)
    @n = 0
  end

  teardown { Rails.cache = @original_cache }

  def episode(location, air_date)
    Episode.create!(season: @season, number_in_season: (@n += 1), title: "Ep #{@n}", location: location, air_date: air_date)
  end

  def with_env(vars)
    old = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  def sitemap_locs
    get "/sitemap.xml"
    Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
  end

  # ---------- food sources ----------

  test "a food source in one episode is noindex, follow and not in the sitemap" do
    FoodSource.create!(episode: episode(@cr, Date.new(2015, 3, 1)), name: "iguana", category: "animal")
    get "/food_sources/iguana"
    assert_response :success
    assert_equal "noindex, follow", robots_meta
    assert_equal "noindex, follow", response.headers["X-Robots-Tag"]
    assert_not_includes sitemap_locs, "#{HOST}/food_sources/iguana"
  end

  test "a food source in two episodes is indexed, listed in the sitemap, and shows facts from the data" do
    ep1 = episode(@cr, Date.new(2015, 3, 1))
    ep2 = episode(@za, Date.new(2017, 6, 1))
    ann = Survivor.create!(full_name: "Ann Alpha")
    FoodSource.create!(episode: ep1, name: "frog", category: "animal", quantity: 3, method: "hunted", survivor_ids: [ ann.id ])
    FoodSource.create!(episode: ep2, name: "frog", category: "animal", quantity: 2, method: "fished")
    get "/food_sources/frog"
    assert_response :success
    assert_nil robots_meta
    assert_nil response.headers["X-Robots-Tag"]

    facts = css_select("#facts-heading").first.ancestors("section").first.text.squish
    assert_includes facts, "Frog was recorded as an animal food source in 2 episodes across 1 season of Naked and Afraid (2015–2017)."
    assert_includes facts, "It happened in Costa Rica and South Africa."
    assert_includes facts, "Recorded methods: fished (1) and hunted (1)."
    assert_includes facts, "A quantity is recorded for 2 of 2 entries, 5 in total."
    assert_includes facts, "1 survivalist is credited with it"
    assert_select "section[aria-labelledby=facts-heading] a[href=?]", "/episodes/by_country/south-africa", text: "South Africa"
    assert_select "section[aria-labelledby=facts-heading] a[href=?]", episode_path(ep2)
    assert description.start_with?("Frog was recorded as an animal food source in 2 episodes")
    assert_operator description.length, :<=, 160
    assert_includes sitemap_locs, "#{HOST}/food_sources/frog" # (after the page checks: this replaces the response)
  end

  test "the food source threshold can be changed with THIN_FOOD_SOURCE_MIN_EPISODES" do
    FoodSource.create!(episode: episode(@cr, Date.new(2015, 3, 1)), name: "snail", category: "animal")
    with_env("THIN_FOOD_SOURCE_MIN_EPISODES" => "1") do
      get "/food_sources/snail"
      assert_nil robots_meta
      assert_includes sitemap_locs, "#{HOST}/food_sources/snail"
    end
    with_env("THIN_FOOD_SOURCE_MIN_EPISODES" => "3") do
      get "/food_sources/snail"
      assert_equal "noindex, follow", robots_meta
    end
  end

  test "food source table leaves out columns nobody filled" do
    ep = episode(@cr, Date.new(2015, 3, 1))
    FoodSource.create!(episode: ep, name: "crab", category: "animal", quantity: 1)
    FoodSource.create!(episode: episode(@cr, Date.new(2015, 4, 1)), name: "crab", category: "animal", quantity: 1)
    get "/food_sources/crab"
    assert_equal [ "Episode", "Season", "Qty", "Location", "Obtained By" ], css_select("table th").map { |th| th.text.strip }
    assert_select "td", text: "—", count: 0
  end

  # ---------- shelters ----------

  test "a shelter type in one episode is noindex, follow and not in the sitemap; in two it is indexed with facts" do
    EpisodeShelter.create!(episode: episode(@cr, Date.new(2015, 3, 1)), shelter_type: "Lean-to", materials: "palm fronds")
    get "/shelters/lean-to"
    assert_equal "noindex, follow", robots_meta
    assert_equal "noindex, follow", response.headers["X-Robots-Tag"]
    assert_not_includes sitemap_locs, "#{HOST}/shelters/lean-to"

    EpisodeShelter.create!(episode: episode(@za, Date.new(2016, 1, 1)), shelter_type: "Lean-to", materials: "Palm fronds")
    Rails.cache.clear
    get "/shelters/lean-to"
    assert_nil robots_meta
    facts = css_select("#facts-heading").first.ancestors("section").first.text.squish
    assert_includes facts, "Lean-to shelter was built in 2 episodes across 1 season of Naked and Afraid (2015–2016)."
    assert_includes facts, "It happened in Costa Rica and South Africa."
    assert_includes facts, "Materials recorded: palm fronds (2)."
    assert_select "td", text: "—", count: 0
    assert_includes sitemap_locs, "#{HOST}/shelters/lean-to"
  end

  test "the shelter threshold can be changed with THIN_SHELTER_MIN_EPISODES" do
    EpisodeShelter.create!(episode: episode(@cr, Date.new(2015, 3, 1)), shelter_type: "Hammock")
    with_env("THIN_SHELTER_MIN_EPISODES" => "0") do
      get "/shelters/hammock"
      assert_nil robots_meta
      assert_includes sitemap_locs, "#{HOST}/shelters/hammock"
    end
  end
end
