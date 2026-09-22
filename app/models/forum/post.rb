module Forum
  class Post < ApplicationRecord
    self.table_name = "forum_posts"

    MAX_IMAGES_PER_POST = 4
    MAX_IMAGE_BYTES     = 5.megabytes
    # Only formats ActiveStorage can actually build a variant from. A blob that
    # is not variable (a .txt or .pdf) raised on .variant() and 500'd the whole
    # topic page for everyone, on every subsequent visit.
    ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

    # Posts may contain HTML, so this list is the security boundary.
    # Deliberately absent: script, style, iframe, object, embed, form, input,
    # button, link, meta, base and svg — every one of them can execute or
    # exfiltrate. Layout tags are absent too, so a post cannot restructure the
    # page around it.
    ALLOWED_TAGS = %w[
      a abbr b blockquote br code del details dfn em
      h1 h2 h3 h4 h5 h6 hr i img ins kbd li mark ol p pre q s samp
      small span strong sub summary sup
      table tbody td tfoot th thead tr u ul
    ].freeze

    # No style, class or id: style enables defacement and CSS-based tracking,
    # class would let a post borrow Bootstrap's layout utilities, and id can
    # collide with the page's own anchors. No target either, which keeps
    # tabnabbing off the table without needing rel=noopener everywhere.
    ALLOWED_ATTRIBUTES = %w[
      href src alt title width height colspan rowspan start lang dir
    ].freeze

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
      # unsafe: true lets raw HTML through Commonmarker instead of dropping it,
      # so posts can use tags directly. Nothing is trusted on the strength of
      # that — the sanitiser below is now the only thing standing between a
      # post and the page, and it allowlists both tags and attributes.
      raw_html = Commonmarker.to_html(source, options: {
        extension: { table: true, autolink: true, strikethrough: true },
        render:    { hardbreaks: true, unsafe: true }
      })
      self.body_html = ActionController::Base.helpers.sanitize(
        raw_html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES
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
        blob = img.blob
        next if blob.nil?

        if blob.byte_size.to_i > MAX_IMAGE_BYTES
          errors.add(:images, "each image must be under #{MAX_IMAGE_BYTES / 1.megabyte} MB")
          break
        end

        unless ALLOWED_IMAGE_TYPES.include?(blob.content_type)
          errors.add(:images, "must be a JPEG, PNG, GIF or WebP image")
          break
        end
      end
    end
  end
end
