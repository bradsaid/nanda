# app/controllers/seasons_controller.rb
class SeasonsController < ApplicationController
  def show
    @season   = Season.includes(:series).find(params[:id])
    @episodes = @season.episodes
                       .includes(:location)
                       .order("number_in_season ASC NULLS LAST, id ASC")
    @survivors = Survivor
                   .joins(appearances: :episode)
                   .where(episodes: { season_id: @season.id })
                   .with_attached_avatar
                   .distinct
                   .order(Arel.sql("LOWER(full_name) ASC"))
  end

  def index
    @seasons = Season.includes(:series).order("series_id ASC, number ASC")
    @season_services = SeasonsHelper.season_services
  end

end
