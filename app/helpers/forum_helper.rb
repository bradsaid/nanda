module ForumHelper
  def forum_time(time)
    return "" if time.blank?
    if time > 1.day.ago
      "#{time_ago_in_words(time)} ago"
    else
      time.strftime("%b %-d, %Y")
    end
  end

  def forum_user_display(user)
    return "[deleted]" if user.nil?
    user.username.presence || user.email_address.split("@").first
  end

  def forum_subscribed?(topic)
    return false unless logged_in?
    current_user.forum_subscriptions.where(forum_topic_id: topic.id).exists?
  end

  def can_moderate_forum?
    logged_in? && (current_user.admin? || current_user.episode_editor?)
  end

  def can_edit_post?(post)
    return false unless logged_in?
    return true if can_moderate_forum?
    post.user_id == current_user.id && post.created_at > Forum::PostsController::EDIT_WINDOW.ago
  end
end
