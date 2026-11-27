# /episodes/by_region/africa: a hub for one region (continent) of filming locations, built
# only from the episodes whose location's country is listed under the region in
# config/regions.yml (see Regions). An unknown region, or one with no episodes, is a 404;
# another spelling of the slug (case, "&", an alias like /caribbean) 301s to the slug.
class RegionsController < ApplicationController
  include SlugRedirects

  RECENT_EPISODES = 8

  def show
    region = Regions.find(params[:region]) or raise ActiveRecord::RecordNotFound, "Unknown region: #{params[:region]}"
    @summary = Regions.summary(region)
    raise ActiveRecord::RecordNotFound, "No episodes in region: #{region.slug}" unless @summary
    return redirect_permanently(by_region_episodes_path(region: region.slug)) if region.slug != params[:region].to_s

    @region = region
    keys = region.country_keys
    in_region = "TRIM(LOWER(locations.country)) IN (?)"

    @season_count   = Regions.episodes_in(region).distinct.count(:season_id)
    @survivor_count = Appearance.joins(episode: :location).where(in_region, keys).distinct.count(:survivor_id)
    @recent_episodes = Episode.includes(:location, season: :series)
                              .joins(:location).where(in_region, keys)
                              .where("episodes.air_date <= ?", Date.current)
                              .order(Arel.sql("episodes.air_date DESC, episodes.id DESC"))
                              .limit(RECENT_EPISODES)
    @other_regions = Regions.summaries.reject { |s| s.slug == region.slug }
  end
end
