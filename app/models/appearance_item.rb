# app/models/appearance_item.rb
class AppearanceItem < ApplicationRecord
  has_paper_trail
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

  # Display name: prefers a specific subtype (e.g. "elk hide") over the generic
  # item name ("hide"). Falls back to the item's name when no subtype set.
  def display_name
    s = subtype.to_s.strip
    s.empty? ? item&.name : s
  end
end

