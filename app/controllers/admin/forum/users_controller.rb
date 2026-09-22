module Admin
  module Forum
    # Directory of forum members, with the moderation actions that go with it.
    class UsersController < Admin::BaseController
      PER_PAGE = 50

      def index
        @q      = params[:q].to_s.strip
        @filter = params[:filter].to_s.presence_in(%w[banned unverified staff]) || "all"

        scope = User.all
        if @q.present?
          like = "%#{@q.downcase}%"
          scope = scope.where("LOWER(username) LIKE :q OR LOWER(email_address) LIKE :q", q: like)
        end

        scope =
          case @filter
          when "banned"     then scope.banned
          when "unverified" then scope.where(email_verified_at: nil)
          when "staff"      then scope.where(role: [User.roles[:admin], User.roles[:episode_editor]])
          else scope
          end

        @users = scope.order(created_at: :desc).page(params[:page]).per(PER_PAGE)

        # One grouped query each instead of a count per row.
        ids = @users.map(&:id)
        @topic_counts = ::Forum::Topic.active.where(user_id: ids).group(:user_id).count
        @post_counts  = ::Forum::Post.active.where(user_id: ids).group(:user_id).count

        @totals = {
          all:        User.count,
          banned:     User.banned.count,
          unverified: User.where(email_verified_at: nil).count
        }
      end

      def update
        user = User.find(params[:id])

        case params[:decision]
        when "ban"
          if user.admin? || user.episode_editor?
            redirect_to admin_forum_users_path, alert: "Staff accounts cannot be banned from here." and return
          end
          user.update!(banned_at: Time.current, ban_reason: params[:ban_reason].presence || "Banned by a moderator")
          # Sessions are row-backed; clearing them ends any signed-in session.
          user.sessions.delete_all
          redirect_to admin_forum_users_path, notice: "#{display_name(user)} is banned."
        when "unban"
          user.update!(banned_at: nil, ban_reason: nil)
          redirect_to admin_forum_users_path, notice: "#{display_name(user)} is no longer banned."
        else
          redirect_to admin_forum_users_path, alert: "Unknown action."
        end
      end

      private

      def display_name(user) = user.username.presence || user.email_address
    end
  end
end
