module Admin
  class SeasonsController < BaseController
    before_action :require_full_admin!, only: %i[new create edit update destroy]
    before_action :set_season, only: %i[show edit update destroy]

    def index
      @seasons = Season.includes(:series).order("series_id ASC, number ASC")
    end

    def show
      redirect_to edit_admin_season_path(@season)
    end

    def new
      @season = Season.new
    end

    def create
      @season = Season.new(season_params)
      if @season.save
        redirect_to admin_seasons_path, notice: "Season created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @season.update(season_params)
        redirect_to admin_seasons_path, notice: "Season updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @season.destroy
      redirect_to admin_seasons_path, notice: "Season deleted."
    end

    # GET /admin/seasons/:id/latest_episode_participants.json
    # Returns the appearances (survivors + roles + PSR + days) from the most
    # recently aired episode in this season, for pre-populating a new episode
    # form on continuous-story seasons.
    def latest_episode_participants
      season = Season.find(params[:id])
      latest = season.episodes
                     .includes(appearances: :survivor)
                     .order("air_date DESC NULLS LAST, number_in_season DESC, id DESC")
                     .first

      if latest.nil?
        render json: { season_id: season.id, participants: [], note: "No previous episode in this season yet." }
        return
      end

      participants = latest.appearances.map do |a|
        next nil unless a.survivor
        {
          survivor_id:    a.survivor_id,
          full_name:      a.survivor.full_name,
          role:           a.role,
          starting_psr:   a.ending_psr || a.starting_psr,
          days_lasted:    nil,
          result:         nil
        }
      end.compact

      render json: {
        season_id:     season.id,
        from_episode:  { id: latest.id, title: latest.title, number_in_season: latest.number_in_season },
        participants:  participants
      }
    end

    private

    def set_season
      @season = Season.find(params[:id])
    end

    def season_params
      params.require(:season).permit(:series_id, :number, :year, :continuous_story)
    end
  end
end
