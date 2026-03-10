module Admin
  class EpisodesController < BaseController
    before_action :set_episode, only: %i[show edit update destroy]

    def index
      @episodes = Episode.includes(season: :series).includes(:location)
                         .joins(season: :series)
                         .order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC")
    end

    def show
      redirect_to edit_admin_episode_path(@episode)
    end

    def new
      @episode = Episode.new
      @episode.appearances.build
    end

    def create
      @episode = Episode.new(episode_params)
      if @episode.save
        redirect_to admin_episodes_path, notice: "Episode created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @episode.update(episode_params)
        redirect_to admin_episodes_path, notice: "Episode updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @episode.destroy
      redirect_to admin_episodes_path, notice: "Episode deleted."
    end

    private

    def set_episode
      @episode = Episode.includes(
        appearances: [:survivor, { appearance_items: :item }],
        food_sources: :survivor,
        episode_traps: [],
        episode_shelters: []
      ).find(params[:id])
    end

    def episode_params
      params.require(:episode).permit(
        :season_id, :number_in_season, :title, :air_date,
        :scheduled_days, :participant_arrangement, :type_modifiers,
        :location_id, :notes, :synopsis,
        appearances_attributes: [
          :id, :survivor_id, :role, :starting_psr, :ending_psr,
          :days_lasted, :result, :weight_loss, :partner_replacement, :_destroy,
          appearance_items_attributes: [
            :id, :item_id, :source, :quantity, :_destroy
          ]
        ],
        food_sources_attributes: [
          :id, :name, :category, :method, :survivor_id, :tools_used, :notes, :_destroy
        ],
        episode_traps_attributes: [
          :id, :trap_type, :result, :notes, :_destroy, builder_ids: []
        ],
        episode_shelters_attributes: [
          :id, :shelter_type, :materials, :notes, :_destroy, builder_ids: []
        ]
      )
    end
  end
end
