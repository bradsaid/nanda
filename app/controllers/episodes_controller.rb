# app/controllers/episodes_controller.rb
class EpisodesController < ApplicationController
  def index
    if params[:location_id].present?
      loc_id    = params[:location_id].to_i
      @location = Location.find_by(id: loc_id)

      @episodes = Episode
        .joins(season: :series)
        .includes(:location, season: :series, appearances: :survivor)
        .where(location_id: loc_id)
        .order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC")

      # ensure overview vars exist so the view never blows up
      @seasons            = []
      @episodes_by_season = {}
      @episode_counts     = {}
    else
      @seasons = Season.includes(:series).order("series_id ASC, number ASC")
      @episodes_by_season = @seasons.index_with do |s|
        s.episodes.includes(:location).order("number_in_season ASC NULLS LAST, id ASC").limit(3)
      end
      @episode_counts = Episode.group(:season_id).count

      @episodes = Episode
        .joins(season: :series)
        .includes(:location, season: :series, appearances: :survivor)
        .order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC")
    end
  end

  def show
    @episode = Episode
      .includes(:location, season: :series, appearances: [:survivor, { appearance_items: :item }])
      .find(params[:id])
  end
end
