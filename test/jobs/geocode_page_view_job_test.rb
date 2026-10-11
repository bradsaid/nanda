require "test_helper"

class GeocodePageViewJobTest < ActiveJob::TestCase
  setup do
    # The test environment's cache is a null store; these need a real one.
    @was_cache  = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @original_ip_lookup = Geocoder.config[:ip_lookup]
    Geocoder.configure(ip_lookup: :test)
    Geocoder::Lookup::Test.reset
    Geocoder::Lookup::Test.add_stub(
      "8.8.8.8", [{ "country" => "United States", "city" => "Mountain View" }]
    )
    @pv = PageView.create!(path: "/", controller_name: "home", action_name: "index",
                           method: "GET", ip_address: "8.8.8.8")
  end

  teardown do
    Rails.cache = @was_cache
    Geocoder::Lookup::Test.reset
    Geocoder.configure(ip_lookup: @original_ip_lookup)
  end

  test "fills in country and city from the ip" do
    GeocodePageViewJob.perform_now(@pv.id)
    @pv.reload
    assert_equal "United States", @pv.country
    assert_equal "Mountain View", @pv.city
  end

  test "does not touch created_at, which the dashboard buckets on" do
    before = @pv.created_at
    GeocodePageViewJob.perform_now(@pv.id)
    assert_equal before.to_i, @pv.reload.created_at.to_i
  end

  test "is a no-op when the page view already has a country" do
    @pv.update_columns(country: "Canada")
    GeocodePageViewJob.perform_now(@pv.id)
    assert_equal "Canada", @pv.reload.country
  end

  test "is a no-op for a page view that no longer exists" do
    id = @pv.id
    @pv.destroy!
    assert_nothing_raised { GeocodePageViewJob.perform_now(id) }
  end

  test "swallows a geocoding provider failure instead of raising" do
    Geocoder::Lookup::Test.reset  # unstubbed ip raises inside the test lookup
    boom = PageView.create!(path: "/", controller_name: "home", action_name: "index",
                            method: "GET", ip_address: "203.0.113.9")
    assert_nothing_raised { GeocodePageViewJob.perform_now(boom.id) }
    assert_nil boom.reload.country
  end

  def page_view(ip)
    PageView.create!(path: "/", controller_name: "home", action_name: "index",
                     method: "GET", ip_address: ip)
  end

  test "an address is looked up once, then answered from the cache" do
    GeocodePageViewJob.perform_now(@pv.id)
    Geocoder::Lookup::Test.reset # any further lookup would now raise
    again = page_view("8.8.8.8")
    GeocodePageViewJob.perform_now(again.id)
    assert_equal "Mountain View", again.reload.city
  end

  test "a failed lookup is not cached, so the next view retries" do
    Geocoder::Lookup::Test.reset
    GeocodePageViewJob.perform_now(@pv.id)
    assert_nil @pv.reload.country

    Geocoder::Lookup::Test.add_stub("8.8.8.8", [{ "country" => "United States", "city" => "Mountain View" }])
    later = page_view("8.8.8.8")
    GeocodePageViewJob.perform_now(later.id)
    assert_equal "United States", later.reload.country
  end

  test "a reply without a country is not cached" do
    Geocoder::Lookup::Test.add_stub("198.51.100.7", [{ "country" => "", "city" => "" }])
    GeocodePageViewJob.perform_now(page_view("198.51.100.7").id)

    Geocoder::Lookup::Test.add_stub("198.51.100.7", [{ "country" => "Canada", "city" => "Toronto" }])
    later = page_view("198.51.100.7")
    GeocodePageViewJob.perform_now(later.id)
    assert_equal "Canada", later.reload.country
  end
end
