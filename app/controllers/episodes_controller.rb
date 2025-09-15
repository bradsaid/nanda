# app/controllers/episodes_controller.rb
class EpisodesController < ApplicationController
  def index
    # Seasons ordered by Series then season number
    @seasons = Season
                 .includes(:series) # avoid N+1 on series
                 .order("series_id ASC, number ASC")

    # Preload a small preview (first 3) per season
    @episodes_by_season = @seasons.index_with do |s|
      s.episodes
       .includes(:location) # lightweight location info on cards
       .order("number_in_season ASC NULLS LAST, id ASC")
       .limit(3)
    end

    # Episode counts per season for the “View all X” buttons
    @episode_counts = Episode.group(:season_id).count
  end

  def show
    @episode = Episode.includes(:location, season: :series, appearances: [:survivor, { appearance_items: :item }])
                      .find(params[:id])
  end
end
