module Forum
  class ReportsController < BaseController
    before_action :set_post

    def new
      if @post.user_id == current_user.id
        redirect_to forum_topic_path(@post.forum_topic), alert: "You can't report your own post."
        return
      end
      @report = Forum::Report.new
    end

    def create
      if @post.user_id == current_user.id
        redirect_to forum_topic_path(@post.forum_topic), alert: "You can't report your own post."
        return
      end

      @report = Forum::Report.new(report_params)
      @report.reporter    = current_user
      @report.reportable  = @post
      if @report.save
        notify_admin(@report)
        redirect_to forum_topic_path(@post.forum_topic), notice: "Report received. A moderator will review."
      else
        flash.now[:alert] = @report.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_post
      @post = Forum::Post.active.find(params[:post_id])
    end

    def report_params
      key = params[:forum_report] ? :forum_report : :report
      params.require(key).permit(:reason, :notes)
    end

    def notify_admin(report)
      Timeout.timeout(5) do
        ForumMailer.report_filed(report).deliver_now
      end
    rescue => e
      Rails.logger.error "[forum/report] mail failed: #{e.class} #{e.message}"
    end
  end
end
