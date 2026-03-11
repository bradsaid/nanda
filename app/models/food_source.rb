class FoodSource < ApplicationRecord
  belongs_to :episode
  belongs_to :episode_trap, optional: true

  enum :category, { animal: "animal", plant: "plant" }, prefix: true
  enum :method, {
    hunted: "hunted",
    foraged: "foraged",
    fished: "fished",
    trapped: "trapped",
    caught: "caught"
  }, prefix: true

  validates :name, presence: true
  validates :category, presence: true

  before_validation :normalize_name

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
end
