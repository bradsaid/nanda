require "test_helper"

class SurvivorsControllerTest < ActionDispatch::IntegrationTest
  test "the current slug renders" do
    get survivor_path(survivors(:one))
    assert_response :success
  end

  test "a numeric id still renders without redirecting" do
    get "/survivors/#{survivors(:one).id}"
    assert_response :success
  end

  test "an old slug 301s to the current one after a rename" do
    s = Survivor.create!(full_name: "Joesph Prouse")
    old_slug = s.slug
    s.update!(full_name: "Joseph Prouse")

    get "/survivors/#{old_slug}"

    assert_response :moved_permanently
    assert_redirected_to "/survivors/#{s.slug}"
  end

  test "an unknown slug is a 404, not a redirect" do
    get "/survivors/no-such-person"
    assert_response :not_found
  end

  test "% and _ in a survivor search are literal characters" do
    Survivor.create!(full_name: "Wildcard Tester")
    get survivors_path(q: "%")
    assert_response :success
    assert_no_match(/Wildcard Tester/, response.body)

    get survivors_path(q: "W_ldcard")
    assert_no_match(/Wildcard Tester/, response.body)

    get survivors_path(q: "ildcard")
    assert_match(/Wildcard Tester/, response.body)
  end

  test "search misses are cached under a bounded key, not the raw query" do
    was = Rails.cache
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.cache = store
    begin
      long = "nomatch" * 200
      get survivors_path(q: long)
      assert_response :success
      keys = store.instance_variable_get(:@data).keys
      assert keys.any? { |k| k.start_with?("survivors_search_hit/") }
      assert keys.none? { |k| k.include?("nomatch") }, "raw query must not appear in a cache key"
      assert keys.all? { |k| k.length < 100 }
    ensure
      Rails.cache = was
    end
  end
end
