# app/controllers/seasons_controller.rb
class SeasonsController < ApplicationController
  def show
    @season   = Season.includes(:series).find(params[:id])
    @episodes = @season.episodes
                       .includes(:location, appearances: { survivor: { avatar_attachment: :blob } })
                       .order("number_in_season ASC NULLS LAST, id ASC")
    survivor_ids = Appearance
                     .joins(:episode)
                     .where(episodes: { season_id: @season.id })
                     .distinct
                     .pluck(:survivor_id)
    @survivors = Survivor
                   .where(id: survivor_ids)
                   .with_attached_avatar
                   .order(:full_name)
  end

  def index
    @seasons = Season.includes(:series).order("series_id ASC, number ASC")
    @season_services = SeasonsHelper.season_services
  end

end
