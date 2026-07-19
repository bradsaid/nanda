module Forum
  class CategoriesController < BaseController
    def index
      @categories = Forum::Category.ordered
    end

    def show
      @category = Forum::Category.friendly.find(params[:slug])
      @topics = @category.topics
                          .active
                          .includes(:user, :last_post_user)
                          .in_order
                          .page(params[:page]).per(30)
    end
  end
end
