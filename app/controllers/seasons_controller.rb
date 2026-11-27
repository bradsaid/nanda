# app/controllers/seasons_controller.rb
class SeasonsController < ApplicationController
  def show
    @season   = Season.includes(:series).find(params[:id])
    @episodes = @season.episodes
                       .includes(:location, appearances: { survivor: { avatar_attachment: :blob } })
                       .order("number_in_season ASC NULLS LAST, id ASC")
                       .to_a
    survivor_ids = Appearance
                     .joins(:episode)
                     .where(episodes: { season_id: @season.id })
                     .distinct
                     .pluck(:survivor_id)
    @survivors = Survivor
                   .where(id: survivor_ids)
                   .with_attached_avatar
                   .order(:full_name)
                   .to_a

    # Facts for the at-a-glance card, the highlights and the FAQ, computed from the
    # episodes and appearances loaded above (no further queries except the one grouped
    # "items brought" query, run only when the highlights render).
    @overview = EpisodeSetOverview.new(@episodes)

    siblings = Season.where(series_id: @season.series_id)
    @prev_season = siblings.where("number < ?", @season.number).order(number: :desc).first if @season.number
    @next_season = siblings.where("number > ?", @season.number).order(:number).first if @season.number
  end

  def index
    # :episodes is preloaded (one query) because the table, the JSON-LD and the page
    # all count each season's episodes; without it that is one COUNT query per season.
    @seasons = Season.includes(:series, :episodes).order("series_id ASC, number ASC")
    @season_services = SeasonsHelper.season_services
    @franchise_stats = FranchiseStats.fetch
  end

end
