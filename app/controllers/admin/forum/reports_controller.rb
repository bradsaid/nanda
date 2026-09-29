module Admin
  module Forum
    class ReportsController < Admin::BaseController
      def index
        @open      = ::Forum::Report.status_open.order(created_at: :desc).limit(200)
        @handled   = ::Forum::Report.where.not(status: "open").order(handled_at: :desc).limit(50)
        @open_count = @open.size
      end

      def update
        @report = ::Forum::Report.find(params[:id])
        case params[:decision]
        when "dismiss"
          @report.update!(status: :dismissed, handled_by: current_admin, handled_at: Time.current)
          redirect_to admin_forum_reports_path, notice: "Dismissed."
        when "remove_post"
          if @report.reportable.is_a?(::Forum::Post)
            @report.reportable.update!(deleted_at: Time.current)
            @report.update!(status: :actioned, handled_by: current_admin, handled_at: Time.current)
            redirect_to admin_forum_reports_path, notice: "Post removed."
          else
            redirect_to admin_forum_reports_path, alert: "Target is not a post."
          end
        when "lock_topic"
          topic = @report.reportable.is_a?(::Forum::Post) ? @report.reportable.forum_topic : @report.reportable
          topic.update!(locked: true)
          @report.update!(status: :actioned, handled_by: current_admin, handled_at: Time.current)
          redirect_to admin_forum_reports_path, notice: "Topic locked."
        when "ban_user"
          user = @report.reportable.respond_to?(:user) ? @report.reportable.user : nil
          if user
            user.update!(banned_at: Time.current, ban_reason: params[:ban_reason].presence || "Reported content")
            user.sessions.delete_all
            @report.update!(status: :actioned, handled_by: current_admin, handled_at: Time.current)
            redirect_to admin_forum_reports_path, notice: "User banned."
          else
            redirect_to admin_forum_reports_path, alert: "No user to ban."
          end
        else
          redirect_to admin_forum_reports_path, alert: "Unknown decision."
        end
      end
    end
  end
end
