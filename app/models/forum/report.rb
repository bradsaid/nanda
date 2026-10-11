module Forum
  class Report < ApplicationRecord
    self.table_name = "forum_reports"

    # validate: true turns an unknown reason into a validation error rather than
    # an ArgumentError (a 500) when a hand-crafted form posts one.
    enum :reason, { spam: 0, abuse: 1, off_topic: 2, other: 3 }, prefix: true, validate: true
    enum :status, { open: 0, dismissed: 1, actioned: 2 }, prefix: true

    belongs_to :reporter,   class_name: "User"
    belongs_to :reportable, polymorphic: true
    belongs_to :handled_by, class_name: "User", optional: true

    validates :reason, presence: true
    validates :status, presence: true
    validate  :not_already_reported_by_reporter, on: :create

    scope :open_first, -> { order(status: :asc, created_at: :desc) }

    private

    # One open report per member per post; repeats only add noise to the queue.
    def not_already_reported_by_reporter
      return if reporter_id.blank? || reportable.blank?
      if self.class.status_open.exists?(reporter_id: reporter_id, reportable_type: reportable_type, reportable_id: reportable_id)
        errors.add(:base, "You have already reported this and a moderator has not reviewed it yet")
      end
    end
  end
end
