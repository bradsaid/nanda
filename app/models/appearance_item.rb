class AppearanceItem < ApplicationRecord
  belongs_to :appearance
  belongs_to :item
  scope :brought, -> { where(source: "brought") }
  scope :given,   -> { where(source: "given") }

  has_one :brought_ai, -> { where(source: "brought") }, class_name: "AppearanceItem"
  has_one :brought_item, through: :brought_ai, source: :item

  has_many :given_ais, -> { where(source: "given") }, class_name: "AppearanceItem"
  has_many :given_items, through: :given_ais, source: :item

  enum :source, {
    brought: "brought",
    given:   "given",
    found:   "found",
    earned:  "earned",
    foraged: "foraged"
  }, prefix: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :source, presence: true
  validates :appearance_id, uniqueness: { scope: :source,
                                        conditions: -> { where(source: "brought") },
                                        message: "already has a brought item" }
end
