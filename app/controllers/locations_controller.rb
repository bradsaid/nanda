# app/controllers/locations_controller.rb
class LocationsController < ApplicationController
  def index
    @locations =
      Location.left_joins(:episodes)
              .select("locations.*, COUNT(DISTINCT episodes.id) AS episodes_count")
              .group("locations.id")

    # Countries table (kept as-is if you like)
    rows = Episode.joins(:location, season: :series)
                  .where.not(locations: { country: [nil, ""] })
                  .group("locations.country")
                  .select(
                    "locations.country",
                    <<~SQL.squish
                      COUNT(
                        DISTINCT
                        CASE
                          WHEN #{continuous_flag_sql}
                            THEN (series.id::text || '-' || locations.country)
                          ELSE episodes.id::text
                        END
                      ) AS eps_adj_count
                    SQL
                  )
                  .order("eps_adj_count DESC, locations.country ASC")

    @countries_by_eps_adj = rows.map { |r| [r.country, r.eps_adj_count.to_i] }

    respond_to do |format|
      format.html
      format.json do
        render json: @locations
          .select { |l| l.latitude.present? && l.longitude.present? }
          .map { |l|
            {
              id: l.id,
              name: l.site.presence || l.region.presence || l.country,
              address: l.full_address,
              lat: l.latitude,
              lng: l.longitude,
              episodes_count: l.try(:episodes_count).to_i,
              # You can handle this param in EpisodesController (filter by location_id)
              episodes_url: Rails.application.routes.url_helpers.episodes_path(location_id: l.id)
            }
          }
      end
    end
  end
end
