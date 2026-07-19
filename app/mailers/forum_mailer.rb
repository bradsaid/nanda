class ForumMailer < ApplicationMailer
  # Sent to each subscriber when a new reply lands (skipping the post author).
  def new_reply(subscriber, post)
    @user  = subscriber
    @post  = post
    @topic = post.forum_topic
    @url   = forum_topic_url(@topic, anchor: "post-#{@post.id}")
    mail subject: "New reply: #{@topic.title}", to: subscriber.email_address
  end

  # Notifies bradsaid@gmail.com whenever any report is filed.
  def report_filed(report)
    @report = report
    @target = report.reportable
    @url    = report.reportable.is_a?(Forum::Post) ?
                forum_topic_url(@target.forum_topic, anchor: "post-#{@target.id}") :
                forum_topic_url(@target)
    mail subject: "[forum] Report: #{report.reason.humanize}", to: "bradsaid@gmail.com"
  end
end
