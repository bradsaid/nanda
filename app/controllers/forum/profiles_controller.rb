module Forum
  class ProfilesController < BaseController
    def show
      @user = User.where("LOWER(username) = ?", params[:username].to_s.downcase).first
      raise ActionController::RoutingError, "Not Found" unless @user

      @posts_count  = @user.forum_posts.active.count
      @topics_count = @user.forum_topics.active.count
      @recent_posts = @user.forum_posts.active
                            .includes(forum_topic: :forum_category)
                            .order(created_at: :desc)
                            .limit(20)
      @member_since = @user.created_at
      @role_badge   = @user.admin? ? "Admin" : (@user.episode_editor? ? "Editor" : nil)
    end
  end
end
