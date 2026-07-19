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

    validates :title, presence: true, length: { in: 3..150 }

    scope :active,   -> { where(deleted_at: nil) }
    scope :recent,   -> { order(pinned: :desc, last_post_at: :desc) }
    scope :in_order, -> { order(pinned: :desc, last_post_at: :desc, created_at: :desc) }

    def category = forum_category  # alias for readability
    def soft_deleted?   = deleted_at.present?
    def to_param        = slug

    def should_generate_new_friendly_id?
      title_changed? || slug.blank?
    end
  end
end
