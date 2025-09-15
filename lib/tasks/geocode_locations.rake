# lib/tasks/geocode_locations.rake
namespace :locations do
  desc "Force geocode ALL locations (overwrites lat/lng)"
  task geocode_all: :environment do
    require "geocoder"

    total = Location.count
    puts "Geocoding ALL #{total} locations…"

    Location.find_each.with_index(1) do |loc, i|
      site    = loc.respond_to?(:site)    ? loc.site.to_s.strip    : ""
      region  = loc.respond_to?(:region)  ? loc.region.to_s.strip  : ""
      country = loc.respond_to?(:country) ? loc.country.to_s.strip : ""

      addr = [site, region, country].reject(&:blank?).join(", ")

      if addr.blank?
        puts "[#{i}/#{total}] SKIP #{loc.id} — no address fields"
        next
      end

      begin
        result = Geocoder.search(addr).first
        if result
          lat = result.latitude.to_f
          lng = result.longitude.to_f
          loc.update_columns(latitude: lat, longitude: lng)
          puts "[#{i}/#{total}] OK #{loc.id} -> #{lat},#{lng} (#{addr})"
        else
          puts "[#{i}/#{total}] MISS #{loc.id} — no result for '#{addr}'"
        end
      rescue => e
        puts "[#{i}/#{total}] ERR #{loc.id} — #{e.class}: #{e.message}"
      end

      sleep 1.0 # be nice to Nominatim
    end
  end
end
