# app/controllers/locations_controller.rb
class LocationsController < ApplicationController
  def index
    @q    = params[:q].to_s.strip
    @sort = params[:sort].to_s.presence_in(%w[challenges name]) || "challenges"

    # Map pins show challenges, not episodes: every episode is its own
    # challenge, except a continuous-story season, which is a single challenge
    # no matter how many episodes it spans (same rule as the country totals).
    @locations =
      Location.left_joins(:episodes)
              .joins("LEFT JOIN seasons ON seasons.id = episodes.season_id")
              .joins("LEFT JOIN series ON series.id = seasons.series_id")
              .select(<<~SQL.squish)
                locations.*,
                COUNT(DISTINCT episodes.id) AS episodes_count,
                COUNT(
                  DISTINCT
                  CASE
                    WHEN #{continuous_flag_sql} THEN ('season-' || seasons.id::text)
                    ELSE ('episode-' || episodes.id::text)
                  END
                ) AS challenges_count
              SQL
              .group("locations.id")

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
                            THEN (seasons.id::text || '-' || locations.country)
                          ELSE episodes.id::text
                        END
                      ) AS eps_adj_count
                    SQL
                  )
                  .order("eps_adj_count DESC, locations.country ASC")

    @countries_by_eps_adj = rows.map { |r| [r.country, r.eps_adj_count.to_i] }

    @country_challenges = @countries_by_eps_adj.dup
    if @q.present?
      needle = @q.downcase
      @country_challenges = @country_challenges.select { |c, _| c.to_s.downcase.include?(needle) }
    end
    @country_challenges =
      case @sort
      when "name"
        @country_challenges.sort_by { |c, _| c.to_s.downcase }
      else
        @country_challenges.sort_by { |c, n| [-n.to_i, c.to_s.downcase] }
      end

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
              challenges_count: l.try(:challenges_count).to_i,
              episodes_count: l.try(:episodes_count).to_i,
              # You can handle this param in EpisodesController (filter by location_id)
              episodes_url: Rails.application.routes.url_helpers.episodes_path(location_id: l.id)
            }
          }
      end
    end
  end
end
