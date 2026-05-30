class FoodSource < ApplicationRecord
  has_paper_trail
  belongs_to :episode
  belongs_to :episode_trap, optional: true

  enum :category, { animal: "animal", plant: "plant" }, prefix: true
  enum :method, {
    hunted: "hunted",
    foraged: "foraged",
    fished: "fished",
    trapped: "trapped",
    caught: "caught",
    found: "found"
  }, prefix: true

  validates :name, presence: true
  validates :category, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  before_validation :normalize_name
  before_validation :clear_quantity_for_plants

  scope :animals, -> { where(category: "animal") }
  scope :plants,  -> { where(category: "plant") }

  def survivor_ids=(values)
    super(Array(values).reject(&:blank?).map(&:to_i))
  end

  def survivors
    Survivor.where(id: survivor_ids) if survivor_ids.present?
  end

  def obtained_by_label
    survivors&.pluck(:full_name)&.join(", ").presence || "Team"
  end

  private

  def normalize_name
    self.name = name.to_s.strip.downcase if name.present?
  end

  def clear_quantity_for_plants
    self.quantity = nil if category_plant?
  end
end
