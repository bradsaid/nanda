require "test_helper"

class LocationTest < ActiveSupport::TestCase
  # Geocoder would call out to Nominatim; count the calls instead.
  def with_geocode_counter(location)
    calls = 0
    location.define_singleton_method(:geocode) { calls += 1 }
    yield
    calls
  end

  setup do
    @location = Location.create!(country: "Costa Rica", region: "Guanacaste", site: "Test Site", latitude: 10.0, longitude: -85.0)
  end

  test "a location that already has coordinates is not re-geocoded when nothing changed" do
    loc = Location.find(@location.id)
    assert_equal 0, with_geocode_counter(loc) { loc.valid? }
  end

  test "changing the site re-geocodes even though coordinates exist" do
    loc = Location.find(@location.id)
    loc.site = "A different site"
    assert_equal 1, with_geocode_counter(loc) { loc.valid? }
  end

  test "changing the region or country re-geocodes" do
    loc = Location.find(@location.id)
    loc.region = "Puntarenas"
    assert_equal 1, with_geocode_counter(loc) { loc.valid? }

    loc = Location.find(@location.id)
    loc.country = "Panama"
    assert_equal 1, with_geocode_counter(loc) { loc.valid? }
  end

  test "a new location that arrives with coordinates keeps them without a lookup" do
    loc = Location.new(country: "Peru", latitude: -9.19, longitude: -75.01)
    assert_equal 0, with_geocode_counter(loc) { loc.valid? }
  end

  test "coordinates set by hand in the same save are not overwritten by a lookup" do
    loc = Location.find(@location.id)
    loc.assign_attributes(site: "Moved", latitude: 9.5, longitude: -84.0)
    assert_equal 0, with_geocode_counter(loc) { loc.valid? }
  end

  test "a location with no coordinates is geocoded" do
    loc = Location.find(@location.id)
    loc.latitude = nil
    assert_equal 1, with_geocode_counter(loc) { loc.valid? }
  end

  test "country, region and site are stripped" do
    loc = Location.find(@location.id)
    loc.assign_attributes(country: "  Peru ", region: "", site: nil)
    loc.define_singleton_method(:geocode) { }
    loc.valid?
    assert_equal "Peru", loc.country
    assert_nil loc.region
    assert_nil loc.site
  end
end
