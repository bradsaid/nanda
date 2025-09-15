# app/controllers/locations_controller.rb
class LocationsController < ApplicationController
  def index
    @locations = Location
      .where.not(latitude:  [nil, ""], longitude: [nil, ""])   # ← handle blank strings too
      .left_joins(:episodes)
      .select("locations.*, COUNT(episodes.id) AS episodes_count")
      .group("locations.id")

    puts "LocationsController#index: Found #{@locations.size} locations with coordinates."

    respond_to do |format|
      format.html
      format.json do
        render json: @locations.filter_map { |loc|
          lat = loc.latitude.to_f
          lng = loc.longitude.to_f

          # Skip bad coords (0,0 or non-finite)
          next if !lat.finite? || !lng.finite? || (lat.zero? && lng.zero?)

          {
            id: loc.id,
            name: [loc.site, loc.region, loc.country].compact_blank.join(", "),
            country:  loc.country,
            region:   loc.region,
            site:     loc.site,
            latitude: lat,
            longitude: lng,
            episodes_count: loc.read_attribute(:episodes_count).to_i
          }
        }
      end
    end
  end
end
