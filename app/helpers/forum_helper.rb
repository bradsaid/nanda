module ForumHelper
  def forum_time(time)
    return "" if time.blank?
    if time > 1.day.ago
      "#{time_ago_in_words(time)} ago"
    else
      time.strftime("%b %-d, %Y")
    end
  end

  # Never fall back to the email local-part here — this string is rendered
  # publicly on posts, profiles and report previews.
  def forum_user_display(user)
    return "[deleted]" if user.nil?
    user.username.presence || "member"
  end

  # Renders the user's display name as a link to their forum profile when a
  # username exists, or plain text for anonymized / deleted accounts.
  def forum_user_link(user, class_attr: "text-decoration-none")
    name = forum_user_display(user)
    if user&.username.present?
      link_to name, forum_profile_path(username: user.username), class: class_attr
    else
      content_tag(:span, name)
    end
  end

  # Avatar beside a poster's name. Falls back to an initial disc so every row
  # keeps the same shape whether or not the member uploaded a picture.
  def forum_avatar(user, size: 28)
    style = "width:#{size}px;height:#{size}px;object-fit:cover;flex:0 0 auto;"
    if user&.avatar&.attached?
      image_tag user.avatar.variant(:chip),
                class: "rounded-circle border", style: style, alt: "", loading: "lazy"
    else
      initial = forum_user_display(user).to_s[0, 1].upcase.presence || "?"
      content_tag :span, initial,
                  class: "rounded-circle border d-inline-flex align-items-center justify-content-center bg-light text-muted",
                  style: "#{style}font-size:#{(size * 0.45).round}px;",
                  "aria-hidden": "true"
    end
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
