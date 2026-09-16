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

      # forum_topics.posts_count is a counter cache, so it still counts posts
      # that were soft-deleted (deleted_at set, row kept) and the listing drifts
      # upward by one per deletion. Count the live posts instead — one grouped
      # query for the whole page rather than a query per row.
      @active_post_counts = Forum::Post.active
                                       .where(forum_topic_id: @topics.map(&:id))
                                       .group(:forum_topic_id)
                                       .count
    end
  end
end
