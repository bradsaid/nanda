# app/models/survivor.rb
class Survivor < ApplicationRecord
  extend FriendlyId
  friendly_id :full_name, use: :slugged
  has_many :appearances, dependent: :destroy
  has_many :episodes, through: :appearances
  has_many :appearance_items, through: :appearances

  has_one_attached :avatar do |attachable|
    # Small circular grid tile (Survivors index, chip lists, home cards).
    attachable.variant :thumb,     resize_to_fill: [260, 340], saver: { quality: 82, strip: true }
    # Larger portrait for the survivor show hero + episode participants table.
    attachable.variant :portrait,  resize_to_fill: [520, 680], saver: { quality: 85, strip: true }
    # Tiny inline avatar (Recently Active, episode "chip" links).
    attachable.variant :chip,      resize_to_fill: [80, 80],   saver: { quality: 80, strip: true }
  end

  validates :full_name, presence: true, uniqueness: { case_sensitive: false }

  # Optional: Normalize the slug (e.g., downcase, replace spaces with hyphens)
  def normalize_friendly_id(input)
    input.to_s.to_slug.normalize(transliterations: :russian).to_s  # Adjust transliterations if needed for international names
  end

  # Optional: Regenerate slug if full_name changes
  def should_generate_new_friendly_id?
    full_name_changed? || super
  end
  
end
