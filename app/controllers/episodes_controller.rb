# app/controllers/episodes_controller.rb
class EpisodesController < ApplicationController

  def index

      @country = params[:country].to_s.strip
      if @country.present?
        @episodes =
          Episode
            .includes(:location, season: :series)
            .joins(:location)
            .where("TRIM(LOWER(locations.country)) = ?", @country.downcase)
            .order(Arel.sql("air_date IS NULL, air_date DESC"))

        # keep view happy
        @location = nil
        @season   = nil
        @seasons  = []
        @episodes_by_season = {}
        @episode_counts     = {}

        render :index and return
      end

      if params[:location_id].present?
        @location = Location.find_by(id: params[:location_id].to_i)
        return render status: :not_found, plain: "Location not found" unless @location

        @episodes = Episode.where(location_id: @location.id)
                          .includes(:location, season: :series, appearances: [:survivor, { appearance_items: :item }])
                          .order(Arel.sql("air_date IS NULL, air_date DESC, number_in_season ASC"))
        @seasons = []; @episodes_by_season = {}; @episode_counts = {}

      elsif params[:season_id].present? || (params[:series_id].present? && params[:season].present?)
        @season =
          if params[:season_id].present?
            Season.find_by(id: params[:season_id].to_i)
          else
            Season.find_by(series_id: params[:series_id].to_i, number: params[:season].to_i)
          end
        return render status: :not_found, plain: "Season not found" unless @season

        @episodes = Episode.where(season_id: @season.id)
                          .includes(:location, season: :series, appearances: [:survivor, { appearance_items: :item }])
                          .order("number_in_season ASC")
        @seasons = []; @episodes_by_season = {}; @episode_counts = {}

      else
        @seasons = Season.includes(:series).order("series_id ASC, number ASC")
        @episodes_by_season = @seasons.index_with do |s|
          s.episodes.includes(:location).order("number_in_season ASC NULLS LAST, id ASC").limit(3)
        end
        @episode_counts = Episode.group(:season_id).count

        @episodes = Episode.joins(season: :series)
                          .includes(:location, season: :series, appearances: :survivor)
                          .order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC")
      end
  end

  def show
    @episode = Episode
      .includes(:location, season: :series, appearances: [:survivor, { appearance_items: :item }])
      .find(params[:id])
  end

  def by_country
    @country = params[:country].to_s.strip
    @episodes =
      Episode
        .includes(:location, season: :series, appearances: :survivor)
        .joins(:location)
        .where("TRIM(LOWER(locations.country)) = ?", @country.downcase)
        .order(Arel.sql("air_date IS NULL, air_date DESC"))
  end
  
end
