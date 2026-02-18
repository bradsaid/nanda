class FoodSource < ApplicationRecord
  belongs_to :episode
  belongs_to :survivor, optional: true

  enum :category, { animal: "animal", plant: "plant" }, prefix: true
  enum :method, {
    hunted: "hunted",
    foraged: "foraged",
    found: "found",
    fished: "fished",
    trapped: "trapped",
    caught: "caught"
  }, prefix: true

  validates :name, presence: true
  validates :category, presence: true

  before_validation :normalize_name

  scope :animals, -> { where(category: "animal") }
  scope :plants,  -> { where(category: "plant") }

  def obtained_by_label
    survivor&.full_name || "Team"
  end

  private

  def normalize_name
    self.name = name.to_s.strip.downcase if name.present?
  end
end
