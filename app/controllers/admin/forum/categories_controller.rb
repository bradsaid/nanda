module Admin
  module Forum
    class CategoriesController < Admin::BaseController
      before_action :set_category, only: [:edit, :update, :destroy]

      def index
        @categories = ::Forum::Category.ordered
      end

      def new
        @category = ::Forum::Category.new(position: (::Forum::Category.maximum(:position) || 0) + 10)
      end

      def create
        @category = ::Forum::Category.new(category_params)
        if @category.save
          redirect_to admin_forum_categories_path, notice: "Category created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @category.update(category_params)
          redirect_to admin_forum_categories_path, notice: "Updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @category.topics_count.to_i > 0
          redirect_to admin_forum_categories_path, alert: "Category has topics. Move or delete them first."
        else
          @category.destroy!
          redirect_to admin_forum_categories_path, notice: "Category removed."
        end
      end

      private

      def set_category
        @category = ::Forum::Category.friendly.find(params[:id])
      end

      def category_params
        params.require(:forum_category).permit(:name, :description, :position, :locked)
      end
    end
  end
end
