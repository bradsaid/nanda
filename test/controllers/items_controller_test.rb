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
