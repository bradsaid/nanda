# app/controllers/episodes_controller.rb
class EpisodesController < ApplicationController

  def index
    @series  = params[:series].presence
    @season  = params[:season].presence
    @country = params[:country].presence

    @series_names   = Series.order(:name).pluck(:name)
    @season_numbers = @series.present? ? Season.joins(:series).where(series: { name: @series }).distinct.order(:number).pluck(:number)
                                      : Season.distinct.order(:number).pluck(:number)
    @countries      = Location.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)

    scope = Episode.joins(season: :series)
                  .includes(:location, season: :series, appearances: :survivor) # <-- add this
    scope = scope.where(series:  { name: @series })       if @series
    scope = scope.where(seasons: { number: @season })     if @season
    scope = scope.where(locations: { country: @country }) if @country

    @episodes = scope.order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC")
    if params[:location_id].present?
      scope = (scope || Episode.all).where(location_id: params[:location_id])
    end
    # assign @episodes = scope.order(...)

  end

  def show
    @episode = Episode.includes(:location, season: :series, appearances: [:survivor, { appearance_items: :item }])
                      .find(params[:id])
  end

  scope = Episode.joins(season: :series)
               .includes(:location, { season: :series }, appearances: [:survivor, { appearance_items: :item }])

end
