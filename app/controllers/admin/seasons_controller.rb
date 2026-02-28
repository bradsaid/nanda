module Admin
  class SeasonsController < BaseController
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

    private

    def set_season
      @season = Season.find(params[:id])
    end

    def season_params
      params.require(:season).permit(:series_id, :number, :year, :continuous_story)
    end
  end
end
