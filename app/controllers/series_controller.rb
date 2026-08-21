class SeriesController < ApplicationController
  def show
    @series = Series.find(params[:id])
    @seasons = @series.seasons
                      .includes(episodes: :location)
                      .order(:number)
                      .to_a

    ep_ids = @seasons.flat_map { |s| s.episodes.map(&:id) }
    @episode_count = ep_ids.size
    @survivor_count = Appearance.where(episode_id: ep_ids).distinct.count(:survivor_id)
    @countries      = Location.joins(:episodes)
                              .where(episodes: { id: ep_ids })
                              .distinct
                              .pluck(:country)
                              .compact_blank
                              .uniq
    @first_air = @seasons.flat_map { |s| s.episodes.map(&:air_date) }.compact.min
    @last_air  = @seasons.flat_map { |s| s.episodes.map(&:air_date) }.compact.max
  end

  def index
    @series = Series.left_joins(seasons: :episodes)
                    .select("series.*, COUNT(DISTINCT seasons.id) AS seasons_count, COUNT(DISTINCT episodes.id) AS episodes_count")
                    .group("series.id")
                    .order(:name)
                    .to_a
  end
end
