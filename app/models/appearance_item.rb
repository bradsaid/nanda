class AppearanceItem < ApplicationRecord
  belongs_to :appearance
  belongs_to :item
  scope :brought, -> { where(source: "brought") }
  scope :given,   -> { where(source: "given") }

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
