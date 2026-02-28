module Admin
  class SurvivorsController < BaseController
    before_action :set_survivor, only: %i[show edit update destroy]

    def index
      @survivors = Survivor.order(:full_name)
      @survivors = @survivors.where("full_name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    end

    def show
      redirect_to edit_admin_survivor_path(@survivor)
    end

    def new
      @survivor = Survivor.new
    end

    def create
      @survivor = Survivor.new(survivor_params)
      if @survivor.save
        redirect_to admin_survivors_path, notice: "Survivor created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @survivor.update(survivor_params)
        redirect_to admin_survivors_path, notice: "Survivor updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @survivor.destroy
      redirect_to admin_survivors_path, notice: "Survivor deleted."
    end

    private

    def set_survivor
      @survivor = Survivor.friendly.find(params[:id])
    end

    def survivor_params
      params.require(:survivor).permit(
        :full_name, :bio, :instagram, :facebook, :youtube,
        :website, :onlyfans, :merch, :cameo, :other, :avatar
      )
    end
  end
end
