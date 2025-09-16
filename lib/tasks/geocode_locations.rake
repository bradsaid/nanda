# lib/tasks/geocode_locations.rake
namespace :locations do
  desc "Geocode all locations missing coordinates"
  task geocode_all: :environment do
    count = 0
    Location.find_each do |loc|
      next if loc.latitude.present? && loc.longitude.present?
      print "Geocoding: #{loc.full_address}… "
      if loc.valid? && loc.save
        puts "OK (#{loc.latitude}, #{loc.longitude})"
        count += 1
      else
        puts "SKIP (invalid)"
      end
    end
    puts "Geocoded #{count} locations."
  end
end
