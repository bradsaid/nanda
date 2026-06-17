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
    #
    # ?exclude_episode_id= drops a specific episode from consideration —
    # used when this is called from the EDIT form so the "previous" episode
    # is genuinely previous, not the one being edited.
    #
    # Survivors who have already tapped / been eliminated / completed (any
    # appearance with result != nil on the source episode or an earlier one)
    # are filtered out — they shouldn't carry forward into the next episode.
    def latest_episode_participants
      season = Season.find(params[:id])

      episodes_scope = season.episodes
      if params[:exclude_episode_id].present?
        episodes_scope = episodes_scope.where.not(id: params[:exclude_episode_id])
      end

      latest = episodes_scope
                 .includes(:location, appearances: :survivor)
                 .order("air_date DESC NULLS LAST, number_in_season DESC, id DESC")
                 .first

      if latest.nil?
        render json: { season_id: season.id, participants: [], location_id: nil, note: "No previous episode in this season yet." }
        return
      end

      exited_survivor_ids = Appearance
        .joins(:episode)
        .where("episodes.season_id = ?", season.id)
        .where("episodes.air_date <= ?", latest.air_date || Date.new(9999, 1, 1))
        .where.not(result: [nil, ""])
        .pluck(:survivor_id)
        .to_set

      participants = latest.appearances.map do |a|
        next nil unless a.survivor
        next nil if exited_survivor_ids.include?(a.survivor_id)
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
        season_id:               season.id,
        continuous_story:        season.continuous_story_effective?,
        from_episode:            { id: latest.id, title: latest.title, number_in_season: latest.number_in_season },
        location_id:             latest.location_id,
        scheduled_days:          latest.scheduled_days,
        participant_arrangement: latest.participant_arrangement,
        type_modifiers:          latest.type_modifiers,
        participants:            participants
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
