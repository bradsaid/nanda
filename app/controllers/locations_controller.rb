# app/controllers/locations_controller.rb
class LocationsController < ApplicationController
  def index
    @locations = Location.left_joins(:episodes)
                         .select("locations.*, COUNT(episodes.id) AS episodes_count")
                         .group("locations.id")

    respond_to do |format|
      format.html
      format.json do
        render json: @locations.filter_map { |loc|
          lat = loc.latitude
          lng = loc.longitude
          next if lat.blank? || lng.blank?
          lat = lat.to_f; lng = lng.to_f
          next if lat.zero? && lng.zero?

          {
            id: loc.id,
            name: [loc.site, loc.region, loc.country].compact_blank.join(", "),
            country:  loc.country,
            region:   loc.region,
            site:     loc.site,
            latitude:  lat,
            longitude: lng,
            episodes_count: loc.read_attribute(:episodes_count).to_i,
            episodes_url: view_context.episodes_path(location_id: loc.id)
          }
        }
      end
    end
  end
end
