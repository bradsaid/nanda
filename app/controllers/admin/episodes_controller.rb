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
      @episode = Episode.find(params[:id])
    end

    def episode_params
      params.require(:episode).permit(
        :season_id, :number_in_season, :title, :air_date,
        :scheduled_days, :participant_arrangement, :type_modifiers,
        :location_id, :notes, :synopsis
      )
    end
  end
end
