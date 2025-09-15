# app/controllers/seasons_controller.rb
class SeasonsController < ApplicationController
  def show
    @season   = Season.includes(:series).find(params[:id])
    @episodes = @season.episodes
                       .includes(:location)
                       .order("number_in_season ASC NULLS LAST, id ASC")
  end
end
