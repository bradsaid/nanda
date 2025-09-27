# app/models/episode.rb
class Episode < ApplicationRecord
  belongs_to :season
  belongs_to :location, optional: true   # ← allow nil for Solo

  has_many :appearances, dependent: :destroy
  has_many :appearance_items, through: :appearances
  has_many :survivors, through: :appearances

  validates :title, :number_in_season, presence: true

  # Optional: enforce location for non-Solo series only
  validate :location_required_unless_solo

  private
  def location_required_unless_solo
    return if location_id.present?
    return if season&.series&.name&.strip&.downcase == "naked and afraid: solo"
    errors.add(:location, "must exist")
  end
end