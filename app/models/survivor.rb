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
    # og:image / twitter:image (ShareImageHelper). Square and always JPEG so scrapers
    # that cannot read WebP/AVIF or EXIF-rotated uploads get a plain 600x600 picture.
    attachable.variant :share,     resize_to_fill: [600, 600], format: :jpeg, saver: { quality: 85, strip: true }
  end

  validates :full_name, presence: true, uniqueness: { case_sensitive: false }

  # ----- Search aliases: spelling variants and nicknames ("Ally", "Analis") -----
  MAX_ALIASES      = 20
  MAX_ALIAS_LENGTH = 60

  before_validation :normalize_aliases

  # Quick facts (all optional, admin-entered; nothing renders until they are filled in).
  # Publicly shared basics only: no fields for anything personal.
  MIN_BIRTH_YEAR = 1900
  validates :birth_year, numericality: { only_integer: true, greater_than_or_equal_to: MIN_BIRTH_YEAR }, allow_nil: true
  validate  :birth_year_not_in_the_future
  before_validation :normalize_quick_facts

  # Survivors whose name OR any alias contains `like` (an already-escaped "%text%" pattern).
  # Used by the survivors search so "ally", "analis" or "jarrel" find the person.
  scope :matching_name_or_alias, lambda { |like|
    where("survivors.full_name ILIKE :q OR EXISTS (SELECT 1 FROM unnest(survivors.aliases) AS alias_name WHERE alias_name ILIKE :q)", q: like)
  }

  # Tidy a list of aliases: strip, squish, drop blanks and anything equal to the survivor's
  # own name, dedupe case-insensitively (first spelling wins), cap the length of each and
  # the number kept. Accepts an Array or a comma/semicolon/newline separated String.
  def self.clean_aliases(value, full_name: nil)
    list = value.is_a?(String) ? value.split(/[,;\n]/) : Array(value)
    seen = { full_name.to_s.squish.downcase => true }
    list.filter_map do |raw|
      text = raw.to_s.squish.first(MAX_ALIAS_LENGTH).strip
      next if text.blank?
      key = text.downcase
      next if seen[key]
      seen[key] = true
      text
    end.first(MAX_ALIASES)
  end

  # The admin form's single comma-separated field.
  def aliases_text
    Array(aliases).join(", ")
  end

  def aliases_text=(value)
    self.aliases = self.class.clean_aliases(value, full_name: full_name)
  end

  # Aliases worth showing: tidy, never the name itself.
  def display_aliases
    self.class.clean_aliases(aliases, full_name: full_name)
  end

  # Age is only ever approximate (a birth year, not a date): this year minus the year.
  def approximate_age(today = Date.current)
    return nil unless birth_year
    today.year - birth_year
  end

  def quick_facts?
    birth_year.present? || hometown.present? || nationality.present?
  end

  # Optional: Normalize the slug (e.g., downcase, replace spaces with hyphens)
  def normalize_friendly_id(input)
    input.to_s.to_slug.normalize(transliterations: :russian).to_s  # Adjust transliterations if needed for international names
  end

  # Optional: Regenerate slug if full_name changes
  def should_generate_new_friendly_id?
    full_name_changed? || super
  end

  private

  def normalize_aliases
    return unless has_attribute?(:aliases)
    cleaned = self.class.clean_aliases(aliases, full_name: full_name)
    self.aliases = cleaned.presence
  end

  def normalize_quick_facts
    self.hometown    = hometown.to_s.squish.first(120).presence    if has_attribute?(:hometown)
    self.nationality = nationality.to_s.squish.first(80).presence  if has_attribute?(:nationality)
  end

  def birth_year_not_in_the_future
    return if birth_year.blank?
    errors.add(:birth_year, "cannot be in the future") if birth_year > Date.current.year
  end

end
