class SeriesController < ApplicationController
  # Series with at most this many episodes list every episode (with recap excerpts) on the
  # hub; bigger ones (the original series, XL) link to their season pages instead.
  EPISODE_LIST_LIMIT = 60
  # Cast is listed on the hub only up to this many survivalists.
  CAST_LIST_LIMIT = 80

  def show
    @series = Series.find(params[:id])
    @seasons = @series.seasons
                      .includes(episodes: :location)
                      .order(:number)
                      .to_a

    @episodes = @seasons.flat_map { |s| s.episodes.sort_by { |e| [e.number_in_season || 999, e.id] } }
    # One preload for the cast of every episode; avatars only when the cast is listed.
    ActiveRecord::Associations::Preloader.new(records: @episodes, associations: { appearances: :survivor }).call
    @overview = EpisodeSetOverview.new(@episodes)

    @episode_count  = @episodes.size
    @survivor_count = @overview.survivors.size
    @countries      = @overview.countries
    @first_air = @overview.premiere
    @last_air  = @overview.finale

    @list_episodes = @episode_count <= EPISODE_LIST_LIMIT
    @list_cast     = @survivor_count.positive? && @survivor_count <= CAST_LIST_LIMIT
    if @list_cast
      ActiveRecord::Associations::Preloader.new(records: @overview.survivors, associations: { avatar_attachment: :blob }).call
    end
  end

  def index
    @series = Series.left_joins(seasons: :episodes)
                    .select("series.*, COUNT(DISTINCT seasons.id) AS seasons_count, COUNT(DISTINCT episodes.id) AS episodes_count")
                    .group("series.id")
                    .order(:name)
                    .to_a
    @franchise_stats = FranchiseStats.fetch
  end
end
