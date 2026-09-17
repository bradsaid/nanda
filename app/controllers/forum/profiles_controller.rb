module Forum
  class ProfilesController < BaseController
    before_action :set_user
    before_action :require_owner, only: [:edit, :update]

    def show
      @posts_count  = @user.forum_posts.active.count
      @topics_count = @user.forum_topics.active.count
      @recent_posts = @user.forum_posts.active
                            .includes(forum_topic: :forum_category)
                            .order(created_at: :desc)
                            .limit(20)
      @member_since = @user.created_at
      @role_badge   = @user.admin? ? "Admin" : (@user.episode_editor? ? "Editor" : nil)
    end

    def edit
      @avatar_preview = @user.avatar
    end

    def update
      if @user.update(profile_params)
        redirect_to forum_profile_path(username: @user.username), notice: "Profile updated."
      else
        # A rejected upload (too large, wrong type) is still assigned to @user
        # in memory and was never saved, so rendering a variant preview from it
        # raised "Cannot get a signed_id for a new record" and 500'd the page.
        # Preview the avatar that is actually stored instead.
        @avatar_preview = User.find(@user.id).avatar
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.where("LOWER(username) = ?", params[:username].to_s.downcase).first
      raise ActionController::RoutingError, "Not Found" unless @user
    end

    def require_owner
      return if current_user&.id == @user.id
      return if admin_signed_in?
      redirect_to forum_profile_path(username: @user.username), alert: "Not your profile."
    end

    def profile_params
      params.require(:user).permit(:bio, :avatar)
    end
  end
end
