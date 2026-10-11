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

    # Through the queue, like every other forum email. Timeout.timeout around a
    # synchronous send can interrupt the SMTP socket mid-write, and it held the
    # reporter's request open for as long as the mail server took.
    def notify_admin(report)
      ForumMailer.report_filed(report).deliver_later
    rescue => e
      Rails.logger.error "[forum/report] mail failed: #{e.class} #{e.message}"
    end
  end
end
