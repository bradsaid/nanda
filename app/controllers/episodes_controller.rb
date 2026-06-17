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
      @sort = params[:sort].to_s

      # Subquery for earliest valid airdate
      sub = Episode
              .where.not(air_date: nil)
              .select("season_id, MIN(air_date) AS first_air_date, MAX(air_date) AS last_air_date")
              .group("season_id")

      case @sort
      when "airdate" # oldest first
        @seasons = Season
                    .joins(:series)
                    .joins("LEFT JOIN (#{sub.to_sql}) epdates ON epdates.season_id = seasons.id")
                    .select("seasons.*, epdates.first_air_date, epdates.last_air_date, series.name AS series_name")
                    .order(Arel.sql("COALESCE(epdates.first_air_date, DATE '9999-12-31') ASC, series.name ASC, seasons.number ASC, seasons.id ASC"))
      when "newest" # newest first
        @seasons = Season
                    .joins(:series)
                    .joins("LEFT JOIN (#{sub.to_sql}) epdates ON epdates.season_id = seasons.id")
                    .select("seasons.*, epdates.first_air_date, epdates.last_air_date, series.name AS series_name")
                    .order(Arel.sql("COALESCE(epdates.last_air_date, DATE '1900-01-01') DESC, series.name ASC, seasons.number ASC, seasons.id ASC"))
      else
        @seasons = Season.includes(:series).order("series_id ASC, number ASC")
      end

      @episodes_by_season = @seasons.index_with do |s|
        s.episodes.includes(:location).order("number_in_season ASC NULLS LAST, id ASC").limit(3)
      end
      @episode_counts = Episode.group(:season_id).count

      season_ids = @seasons.map(&:id)
      @all_episodes_by_season = Episode.where(season_id: season_ids).includes(:location).group_by(&:season_id)
      @survivor_counts_by_season = Appearance.joins(:episode)
                                              .where(episodes: { season_id: season_ids })
                                              .distinct
                                              .group("episodes.season_id")
                                              .count(:survivor_id)

      @episodes = Episode.joins(season: :series)
                        .includes(:location, season: :series, appearances: :survivor)
                        .order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC")
    end
  end

  def show
    @episode = Episode
      .includes(:location, :episode_shelters, :medical_calls, :bushcraft_items, season: :series,
                episode_traps: :food_sources,
                appearances: [{ survivor: { avatar_attachment: :blob } }, { appearance_items: :item }],
                food_sources: :episode_trap)
      .find(params[:id])

    # On continuous-story seasons (XL, Global Showdown, Alone, etc.) the
    # "Copy participants from previous episode" admin button carries every
    # survivor forward to every later episode by default — so the raw
    # appearance list for, say, GS S1 E5 includes survivors who tapped /
    # were eliminated in an earlier episode. Drop any appearance whose
    # survivor has a result recorded on an *earlier* episode this season;
    # the result-bearing episode itself stays visible.
    season = @episode.season
    is_continuous = season && (season.continuous_story || season.series&.continuous_story)
    if is_continuous && @episode.air_date
      exit_air_dates =
        Appearance
          .joins(:episode)
          .where("episodes.season_id = ?", @episode.season_id)
          .where(survivor_id: @episode.appearances.map(&:survivor_id))
          .where.not(result: nil)
          .group(:survivor_id)
          .minimum("episodes.air_date")
      @active_appearances = @episode.appearances.reject do |a|
        d = exit_air_dates[a.survivor_id]
        d && d < @episode.air_date
      end
    else
      @active_appearances = @episode.appearances
    end
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
