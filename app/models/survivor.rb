# app/models/survivor.rb
class Survivor < ApplicationRecord
  extend FriendlyId
  # :history remembers every slug a survivor has had, so renaming someone (the
  # bio verification pass did six) leaves the old /survivors/<slug> URL
  # resolving instead of 404ing. SurvivorsController#show 301s it to the
  # current slug.
  friendly_id :full_name, use: [:slugged, :history]
  has_many :appearances, dependent: :destroy
  has_many :episodes, through: :appearances
  has_many :appearance_items, through: :appearances
  # medical_calls.survivor_id has a foreign key, so deleting a survivor who had
  # a medical call raised PG::ForeignKeyViolation. Keep the call on the episode
  # (reason, tap-out flag, notes) and just drop the link to the person; the
  # episode page already renders a call with no survivor.
  has_many :medical_calls, dependent: :nullify

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
