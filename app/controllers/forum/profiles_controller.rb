module Forum
  class ProfilesController < BaseController
    PER_PAGE = 40

    before_action :set_user, except: [:index]
    # Only the account holder may move their own address — not an admin, who
    # could otherwise take over an account without knowing the password.
    before_action :require_owner, only: [:edit, :update]
    before_action :require_self,  only: [:request_email_change, :cancel_email_change]

    # Public member directory. Deliberately shows nothing an email address
    # could be recovered from — username, picture, join date and activity only.
    def index
      @q = params[:q].to_s.strip
      scope = User.not_banned.where.not(username: [nil, ""])
      scope = scope.where("LOWER(username) LIKE ?", "%#{@q.downcase}%") if @q.present?

      @members = scope.with_attached_avatar
                      .order(Arel.sql("LOWER(username)"))
                      .page(params[:page]).per(PER_PAGE)

      ids = @members.map(&:id)
      @post_counts = ::Forum::Post.active
                                  .joins(:forum_topic)
                                  .where(forum_topics: { deleted_at: nil }, forum_posts: { user_id: ids })
                                  .group(:user_id).count
      @member_total = scope.count
    end

    def show
      # Post.active only checks the post's own deleted_at, so a post inside a
      # removed topic still counted as live — it showed on the profile and
      # linked to a topic that 404s. The topic has to be undeleted too.
      visible_posts = @user.forum_posts
                           .active
                           .joins(:forum_topic)
                           .where(forum_topics: { deleted_at: nil })

      @posts_count  = visible_posts.count
      @topics_count = @user.forum_topics.active.count
      @recent_posts = visible_posts.includes(:forum_topic)
                                   .order(created_at: :desc)
                                   .limit(20)
      @member_since = @user.created_at
      @role_badge   = @user.admin? ? "Admin" : (@user.episode_editor? ? "Editor" : nil)
    end

    def edit
      @avatar_preview   = @user.avatar
      @profile_username = persisted_username
    end

    # Requests an email change. Nothing moves until the new address is
    # confirmed from a link sent to it, and the member's current password is
    # required so a borrowed session cannot quietly take the account over.
    def request_email_change
      unless @user.authenticate(params[:current_password].to_s)
        redirect_to forum_edit_profile_path(username: @user.username),
                    alert: "That password is not correct." and return
      end

      @user.pending_email_address = params[:new_email_address]
      if @user.save
        AuthMailer.confirm_email_change(@user).deliver_later
        AuthMailer.email_change_requested(@user).deliver_later
        redirect_to forum_profile_path(username: @user.username),
                    notice: "Check #{@user.pending_email_address} for a link to confirm the change. "                             "Your current address stays in use until you do."
      else
        redirect_to forum_edit_profile_path(username: @user.username),
                    alert: @user.errors.full_messages.to_sentence.presence || "That address could not be used."
      end
    end

    def cancel_email_change
      @user.update(pending_email_address: nil)
      redirect_to forum_edit_profile_path(username: @user.username),
                  notice: "Email change cancelled."
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
        # Every link on this page is built from the username, and @user is
        # holding the rejected one — which may not even satisfy the route
        # constraint. Build them from the stored name instead, or an invalid
        # username 500s the page rather than showing the error.
        @profile_username = persisted_username
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.where("LOWER(username) = ?", params[:username].to_s.downcase).first
      raise ActionController::RoutingError, "Not Found" unless @user
    end

    # The username as stored, ignoring any unsaved change.
    def persisted_username
      @user.username_changed? ? @user.username_was : @user.username
    end

    def require_self
      return if current_user&.id == @user.id
      redirect_to forum_profile_path(username: @user.username),
                  alert: "You can only change your own email address."
    end

    def require_owner
      return if current_user&.id == @user.id
      return if admin_signed_in?
      redirect_to forum_profile_path(username: @user.username), alert: "Not your profile."
    end

    def profile_params
      params.require(:user).permit(:username, :bio, :avatar)
    end
  end
end
