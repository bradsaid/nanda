module Forum
  class Category < ApplicationRecord
    self.table_name = "forum_categories"

    extend FriendlyId
    friendly_id :name, use: :slugged

    has_many :topics, class_name: "Forum::Topic",
                       foreign_key: :forum_category_id, dependent: :destroy

    validates :name,     presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
    validates :position, presence: true, numericality: { only_integer: true }

    scope :ordered, -> { order(:position, :id) }

    # The forum is a single space; categories survive only because topics need
    # a parent row. Everything new lands in the first one.
    def self.default = ordered.first

    def to_param = slug
  end
end
