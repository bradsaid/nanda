require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @brought_item = Item.create!(name: "zzbroughtonly")
    @given_item   = Item.create!(name: "zzgivenonly")
    AppearanceItem.create!(appearance: appearances(:one), item: @brought_item, source: "brought", quantity: 1)
    AppearanceItem.create!(appearance: appearances(:two), item: @given_item,   source: "given",   quantity: 1)
  end

  test "index renders with no source filter and shows both top cards" do
    get items_path
    assert_response :success
    assert_match "Top Brought Items", @response.body
    assert_match "Top Given Items",   @response.body
  end

  test "source=brought hides the Top Given card" do
    get items_path(source: "brought")
    assert_response :success
    assert_match     "Top Brought Items", @response.body
    assert_no_match(/Top Given Items/,    @response.body)
  end

  test "source=given hides the Top Brought card" do
    get items_path(source: "given")
    assert_response :success
    assert_match     "Top Given Items",  @response.body
    assert_no_match(/Top Brought Items/, @response.body)
  end

  test "search results are restricted to the selected source" do
    get items_path(q: "zz", source: "brought")
    assert_response :success
    assert_match     "zzbroughtonly", @response.body
    assert_no_match(/zzgivenonly/,    @response.body)

    get items_path(q: "zz", source: "given")
    assert_response :success
    assert_match     "zzgivenonly",    @response.body
    assert_no_match(/zzbroughtonly/,   @response.body)
  end

  test "both (blank source) returns rows of either source" do
    get items_path(q: "zz")
    assert_response :success
    assert_match "zzbroughtonly", @response.body
    assert_match "zzgivenonly",   @response.body
  end

  test "an unknown source value is ignored rather than filtering everything out" do
    get items_path(q: "zz", source: "'; DROP TABLE items; --")
    assert_response :success
    assert_match "zzbroughtonly", @response.body
    assert_match "zzgivenonly",   @response.body
    assert Item.exists?(@brought_item.id)
  end

  test "the source select offers all three choices and marks the active one" do
    get items_path(source: "given")
    assert_response :success
    assert_select "select[name=source] option[value='']",        text: /Brought & given/
    assert_select "select[name=source] option[value=brought]",    text: /Brought only/
    assert_select "select[name=source] option[value=given][selected]"
  end

  test "a % or _ in the search is literal, not a wildcard for every item" do
    ["%", "_"].each do |wildcard|
      get items_path(q: wildcard)
      assert_response :success
      assert_select "#items-results", text: /No results found/
      assert_no_match(/Results for/, @response.body)
    end
  end

  test "an absurdly long search string is capped rather than echoed back in full" do
    get items_path(q: "z" * 5_000)
    assert_response :success
    assert_no_match(/z{101}/, @response.body)
  end

  # ----- item show: "brought on N challenges" summary -----

  def build_challenge(series:, season_number:, continuous: false, country: "Peru", episodes: 1, start: Date.new(2024, 1, 7))
    season = Season.create!(series: series, number: season_number, year: 2024, continuous_story: continuous)
    loc    = Location.find_or_create_by!(country: country, site: "Summary #{country}")
    Array.new(episodes) do |i|
      Episode.create!(season: season, location: loc, title: "#{series.name} S#{season_number} Ep#{i + 1}",
                      number_in_season: i + 1, air_date: start + (i * 7))
    end
  end

  def bring(item, episode, survivor_name, source: "brought")
    survivor = Survivor.find_or_create_by!(full_name: survivor_name)
    app = Appearance.create!(survivor: survivor, episode: episode)
    AppearanceItem.create!(appearance: app, item: item, source: source, quantity: 1)
  end

  def summary_text
    css_select("#item-summary").text.squish.gsub("\u00A0", " ")
  end

  test "item summary counts distinct challenges the item was brought on" do
    item = Item.create!(name: "summary knife")
    s    = Series.create!(name: "Summary Normal")
    eps  = build_challenge(series: s, season_number: 1, episodes: 3)
    bring(item, eps[0], "Summary Alice")
    bring(item, eps[1], "Summary Bob")

    get item_path(item)
    assert_response :success
    assert_equal "This item has been brought on 2 challenges.", summary_text
  end

  test "two survivors bringing the item in the same episode is one challenge" do
    item = Item.create!(name: "summary pot")
    eps  = build_challenge(series: Series.create!(name: "Summary Pair"), season_number: 1)
    bring(item, eps[0], "Summary Cara")
    bring(item, eps[0], "Summary Dan")

    get item_path(item)
    assert_equal "This item has been brought on 1 challenge.", summary_text
  end

  test "a continuous season counts as one challenge however many episodes it has" do
    item = Item.create!(name: "summary machete")
    cont = build_challenge(series: Series.create!(name: "Summary Cont"), season_number: 2, continuous: true, episodes: 4)
    norm = build_challenge(series: Series.create!(name: "Summary Norm"), season_number: 1)
    cont.each { |ep| bring(item, ep, "Summary Eve") }
    bring(item, norm[0], "Summary Finn")

    get item_path(item)
    assert_equal "This item has been brought on 2 challenges.", summary_text
  end

  test "two continuous seasons of one series are two challenges, not one" do
    item   = Item.create!(name: "summary bow")
    series = Series.create!(name: "Summary Multi")
    a = build_challenge(series: series, season_number: 1, continuous: true, episodes: 3)
    b = build_challenge(series: series, season_number: 2, continuous: true, episodes: 3, start: Date.new(2025, 1, 5))
    (a + b).each { |ep| bring(item, ep, "Summary Gia") }

    get item_path(item)
    assert_equal "This item has been brought on 2 challenges.", summary_text
  end

  test "the summary follows the country filter" do
    item = Item.create!(name: "summary rope")
    s    = Series.create!(name: "Summary Country")
    peru  = build_challenge(series: s, season_number: 1, country: "Peru", episodes: 2)
    chile = build_challenge(series: s, season_number: 2, country: "Chile", episodes: 1)
    bring(item, peru[0], "Summary Hal")
    bring(item, peru[1], "Summary Hal")
    bring(item, chile[0], "Summary Ida")

    get item_path(item)
    assert_equal "This item has been brought on 3 challenges.", summary_text

    get item_path(item, country: "Peru")
    assert_equal "This item has been brought on 2 challenges in Peru.", summary_text
  end

  test "the summary mentions given challenges separately and handles never-brought items" do
    item = Item.create!(name: "summary fire starter")
    s    = Series.create!(name: "Summary Given")
    eps  = build_challenge(series: s, season_number: 1, episodes: 2)
    bring(item, eps[0], "Summary Jo", source: "brought")
    bring(item, eps[0], "Summary Kai", source: "given")
    bring(item, eps[1], "Summary Kai", source: "given")

    get item_path(item)
    assert_equal "This item has been brought on 1 challenge, and given on 2 challenges.", summary_text

    given_only = Item.create!(name: "summary given only")
    bring(given_only, eps[0], "Summary Lou", source: "given")
    get item_path(given_only)
    assert_equal "This item has never been brought on a challenge, but it has been given on 1 challenge.", summary_text

    get item_path(Item.create!(name: "summary unused"))
    assert_equal "This item has never been brought on a challenge.", summary_text
  end

  test "deleting an item shows up on /items without waiting for the cache to expire" do
    was = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    begin
      get items_path
      assert_match "zzbroughtonly", @response.body

      # The deleted rows were not the most recently touched, so MAX(updated_at)
      # alone would not have changed.
      AppearanceItem.where(item: @brought_item).delete_all
      @brought_item.destroy
      get items_path
      assert_no_match(/zzbroughtonly/, @response.body)
    ensure
      Rails.cache = was
    end
  end
end
