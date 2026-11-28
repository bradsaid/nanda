require "test_helper"

# Every public page type renders a <title> of at most SeoHelper::MAX_TITLE_LENGTH (60)
# characters, even for records with very long names, and the shortened titles keep the key
# entity (series + season + episode, survivor name, country, ...).
class TitleLengthTest < ActionDispatch::IntegrationTest
  LIMIT = SeoHelper::MAX_TITLE_LENGTH

  LONG_SERIES  = "Naked and Afraid: Castaways of the Pacific Ocean Expedition".freeze
  LONG_TITLE   = "The Extraordinarily Long and Winding Road to Nowhere in the Jungle".freeze
  LONG_SURVIVOR = "Maximilian Bartholomew Featherstonehaugh-Montgomery III".freeze
  LONG_ITEM     = "Extra Long Collapsible Titanium Camp Cooking Pot With Folding Handle".freeze
  LONG_COUNTRY  = "Saint Vincent and the Grenadines".freeze
  LONG_FOOD     = "Long-Nosed Spiny Orb-Weaving Tree Frog Species".freeze
  LONG_SHELTER  = "Raised Platform Lean-to With Thatched Palm Roof".freeze

  def title = css_select("head title").first.text

  setup do
    ENV["FORUM_ENABLED"] = "true"
    # /podcasts links to survivors it looks up by name.
    File.read(Rails.root.join("app/views/static_pages/podcasts.html.slim")).scan(/find_by\(full_name: "([^"]+)"\)/).flatten.uniq.each do |name|
      Survivor.find_or_create_by!(full_name: name)
    end
    @flagship = Series.create!(name: "Naked and Afraid")
    @lastone  = Series.create!(name: "Naked and Afraid: Last One Standing")
    @long     = Series.create!(name: LONG_SERIES)
    @xl       = Series.create!(name: "Naked and Afraid XL")
    @loc  = Location.create!(country: "Costa Rica", region: "Guanacaste", site: "Playa Larga", latitude: 10.0, longitude: -85.0)
    @loc2 = Location.create!(country: LONG_COUNTRY, region: "Windward Islands Archipelago", site: "Northern Mountain Rainforest Reserve", latitude: 13.0, longitude: -61.0)
    @episodes = [ [ @flagship, 14, 12 ], [ @lastone, 12, 10 ], [ @long, 11, 14 ], [ @xl, 10, 3 ], [ @flagship, 1, 1 ] ].each_with_index.map do |(series, sn, en), i|
      season = Season.find_or_create_by!(series: series, number: sn) { |s| s.year = 2020 }
      Episode.create!(season: season, number_in_season: en, title: (i.even? ? LONG_TITLE : "Short"), location: (i.even? ? @loc2 : @loc),
                      air_date: Date.new(2020, 1, 1) + i, synopsis: "A synopsis for episode #{i}.")
    end
    @survivor = Survivor.create!(full_name: LONG_SURVIVOR)
    @episodes.each { |ep| Appearance.create!(episode: ep, survivor: @survivor) }
    @item = Item.create!(name: LONG_ITEM, item_type: "cooking pot and other cookware")
    AppearanceItem.create!(appearance: Appearance.first, item: @item, source: "brought")
    2.times { |i| FoodSource.create!(episode: @episodes[i], name: LONG_FOOD.downcase, category: "animal") }
    2.times { |i| EpisodeShelter.create!(episode: @episodes[i], shelter_type: LONG_SHELTER) }
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general), user: users(:one),
                                  title: "What is the very best survival knife for a twenty-one day challenge in the jungle?")
    @topic.posts.create!(user: users(:one), body: "Opening post about knives.")
  end

  teardown { ENV["FORUM_ENABLED"] = nil }

  def public_paths
    paths = %w[/ /about /podcasts /contact /privacy_policy /terms_of_service /forum/guidelines /survivors /episodes /items
               /food_sources /shelters /locations /seasons /series /seasons/latest /shop /shop/guides
               /es/naked-and-afraid-guia-de-episodios /pt/naked-and-afraid-guia-de-episodios /fr/naked-and-afraid-guide-des-episodes
               /forum /forum/users]
    paths += ShopCatalog.guides.map { |g| "/shop/guides/#{g.slug}" }
    paths << survivor_path(@survivor)
    paths += @episodes.map { |ep| episode_path(ep) }
    paths += Season.all.map { |s| season_path(s) } + Series.all.map { |s| series_path(s) }
    paths += [ "/episodes/by_country/costa-rica", "/episodes/by_country/#{NameSlugs.slug(:country, LONG_COUNTRY)}" ]
    paths += Regions.summaries.map { |r| "/episodes/by_region/#{r.slug}" }
    paths << item_path(@item) << "#{item_path(@item)}?country=#{CGI.escape(LONG_COUNTRY)}"
    paths << "/items/types/#{NameSlugs.slug(:item_type, @item.item_type)}"
    paths << "/items/types/#{NameSlugs.slug(:item_type, @item.item_type)}?country=#{CGI.escape(LONG_COUNTRY)}"
    paths << "/food_sources/#{NameSlugs.slug(:food_source, LONG_FOOD)}"
    paths << "/shelters/#{NameSlugs.slug(:shelter, LONG_SHELTER)}"
    paths << "/episodes?location_id=#{@loc2.id}" << "/episodes?season_id=#{Season.find_by!(series: @long).id}"
    paths << forum_topic_path(@topic)
    paths
  end

  test "every public page's <title> is at most #{LIMIT} characters" do
    too_long = []
    public_paths.each do |path|
      get path
      assert_includes [ 200 ], response.status, "#{path} -> #{response.status}"
      t = title.strip
      puts "#{t.length.to_s.rjust(3)} #{t}   (#{path[0, 50]})" if ENV["PRINT_TITLES"]
      too_long << "#{t.length}: #{t.inspect} (#{path})" if t.length > LIMIT
    end
    assert_empty too_long, "titles over #{LIMIT} characters:\n#{too_long.join("\n")}"
  end

  test "shortened titles keep the key entity" do
    ep = @episodes[0] # Naked and Afraid S14 E12, long title
    get episode_path(ep)
    assert_match(/\ANaked and Afraid Season 14 Episode 12: The Extraordinarily/, title)

    get episode_path(@episodes[2]) # long series name
    assert_includes title, "S11E14"
    assert_includes title, "Castaways of the Pacific"

    get episode_path(@episodes[3]) # short enough to keep the full "Season N Episode M" wording
    assert_equal "Naked and Afraid XL Season 10 Episode 3: Short", title

    get survivor_path(@survivor)
    assert title.start_with?("Maximilian Bartholomew")

    get "/episodes/by_country/#{NameSlugs.slug(:country, LONG_COUNTRY)}"
    assert_includes title, LONG_COUNTRY

    get item_path(@item, country: LONG_COUNTRY)
    assert_includes title.downcase, "extra long collapsible"
  end
end
