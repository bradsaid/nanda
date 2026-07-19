module Forum
  class Post < ApplicationRecord
    self.table_name = "forum_posts"

    MAX_IMAGES_PER_POST = 4
    MAX_IMAGE_BYTES     = 5.megabytes

    belongs_to :forum_topic, class_name: "Forum::Topic", counter_cache: :posts_count
    belongs_to :user, counter_cache: :posts_count

    has_many_attached :images
    has_many :reports, as: :reportable, class_name: "Forum::Report", dependent: :destroy

    has_paper_trail on: [:update], only: [:body]

    validates :body, presence: true, length: { in: 1..20_000 }
    validate  :images_within_limits

    before_save :render_html
    after_create_commit :touch_topic_activity
    after_create_commit :notify_subscribers

    scope :active,     -> { where(deleted_at: nil) }
    scope :chronological, -> { order(:created_at) }

    def topic          = forum_topic  # alias for readability
    def soft_deleted?  = deleted_at.present?

    private

    def render_html
      return if body.blank?
      source = body.to_s.dup.force_encoding("UTF-8")
      raw_html = Commonmarker.to_html(source, options: {
        extension: { table: true, autolink: true, strikethrough: true },
        render:    { hardbreaks: true, unsafe: false }
      })
      self.body_html = ActionController::Base.helpers.sanitize(
        raw_html,
        tags: %w[a strong em br p ul ol li code pre blockquote hr],
        attributes: %w[href]
      )
    end

    def touch_topic_activity
      forum_topic.update_columns(
        last_post_at:      created_at,
        last_post_user_id: user_id
      )
    end

    # Email every subscriber except the author. Uses deliver_later so a
    # busy thread with 20 subscribers doesn't block the POST. Solid Queue's
    # :async adapter (in-process pool) is fine here — a lost reply email is
    # not user-critical since the topic still updates in-place.
    def notify_subscribers
      subscriber_ids = forum_topic.subscriptions.where.not(user_id: user_id).pluck(:user_id)
      User.where(id: subscriber_ids).not_banned.find_each do |sub|
        ForumMailer.new_reply(sub, self).deliver_later
      end
    rescue => e
      Rails.logger.error "[forum/post#notify_subscribers] #{e.class} #{e.message}"
    end

    def images_within_limits
      if images.attached? && images.count > MAX_IMAGES_PER_POST
        errors.add(:images, "cap is #{MAX_IMAGES_PER_POST} per post")
      end
      images.each do |img|
        if img.blob.byte_size > MAX_IMAGE_BYTES
          errors.add(:images, "each image must be under #{MAX_IMAGE_BYTES / 1.megabyte} MB")
          break
        end
      end
    end
  end
end
