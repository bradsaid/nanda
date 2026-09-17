module Forum
  class Topic < ApplicationRecord
    self.table_name = "forum_topics"

    extend FriendlyId
    friendly_id :title, use: [:slugged, :scoped], scope: :forum_category

    belongs_to :forum_category, class_name: "Forum::Category", counter_cache: :topics_count
    belongs_to :user
    belongs_to :last_post_user, class_name: "User", optional: true

    has_many :posts, class_name: "Forum::Post",
                      foreign_key: :forum_topic_id, dependent: :destroy
    has_many :subscriptions, class_name: "Forum::Subscription",
                              foreign_key: :forum_topic_id, dependent: :destroy
    has_many :reports, as: :reportable, class_name: "Forum::Report", dependent: :destroy

    # Shared by TopicsController#show (pagination) and PostsController#create
    # (working out which page a brand new reply landed on).
    POSTS_PER_PAGE = 20

    validates :title, presence: true, length: { in: 3..150 }

    # The categories index renders "Last: ..." from forum_categories.last_topic_at,
    # but nothing ever wrote the column, so the line never appeared.
    after_create_commit :touch_category_activity

    scope :active,   -> { where(deleted_at: nil) }
    scope :recent,   -> { order(pinned: :desc, last_post_at: :desc) }
    scope :in_order, -> { order(pinned: :desc, last_post_at: :desc, created_at: :desc) }

    def category = forum_category  # alias for readability
    def soft_deleted?   = deleted_at.present?
    def to_param        = slug

    # Deliberately NOT title_changed?. Regenerating the slug on every title
    # edit silently moved the topic to a new URL and left the old one 404ing,
    # killing bookmarks, cross-links from other threads and indexed results.
    # The slug is minted once and then frozen; the title stays free to change.
    def should_generate_new_friendly_id?
      slug.blank?
    end

    private

    def touch_category_activity
      forum_category.update_columns(last_topic_at: created_at)
    end
  end
end
