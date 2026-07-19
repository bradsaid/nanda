module Forum
  class Report < ApplicationRecord
    self.table_name = "forum_reports"

    enum :reason, { spam: 0, abuse: 1, off_topic: 2, other: 3 }, prefix: true
    enum :status, { open: 0, dismissed: 1, actioned: 2 }, prefix: true

    belongs_to :reporter,   class_name: "User"
    belongs_to :reportable, polymorphic: true
    belongs_to :handled_by, class_name: "User", optional: true

    validates :reason, presence: true
    validates :status, presence: true

    scope :open_first, -> { order(status: :asc, created_at: :desc) }
  end
end
