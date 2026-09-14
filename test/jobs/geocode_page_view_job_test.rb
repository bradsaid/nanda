require "test_helper"

class GeocodePageViewJobTest < ActiveJob::TestCase
  setup do
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
end
