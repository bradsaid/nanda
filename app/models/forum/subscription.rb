module Forum
  class Subscription < ApplicationRecord
    self.table_name = "forum_subscriptions"

    belongs_to :user
    belongs_to :forum_topic, class_name: "Forum::Topic"

    validates :user_id, uniqueness: { scope: :forum_topic_id }
  end
end
