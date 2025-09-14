# app/controllers/locations_controller.rb
class LocationsController < ApplicationController
  def index
    @locations = Location
      .where.not(latitude: nil, longitude: nil)
      .left_joins(:episodes)
      .select("locations.*, COUNT(episodes.id) AS episodes_count")
      .group("locations.id")

    respond_to do |format|
      format.html
      format.json do
        render json: @locations.map { |loc|
          {
            id: loc.id,
            name: [loc.site, loc.region, loc.country].compact_blank.join(", "),
            country: loc.country,
            region:  loc.region,
            site:    loc.site,
            latitude:  loc.latitude.to_f,
            longitude: loc.longitude.to_f,
            episodes_count: loc.read_attribute(:episodes_count).to_i
          }
        }
      end
    end
  end
end
