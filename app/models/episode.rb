# app/models/episode.rb
class Episode < ApplicationRecord
  extend FriendlyId
  has_paper_trail

  # The public URL is /episodes/<slug>, e.g. naked-and-afraid-s14e2-haunted-and-hungry:
  # series + season + episode number + title (titles repeat across series and seasons;
  # series + season + number is unique, so the slug is too). The slug is generated once,
  # when the episode is created (or the first time a pre-slug row is saved), and then
  # FROZEN: editing the title or renumbering never moves the URL, so inbound links and
  # search rankings are not disturbed. :history is still on so that a slug changed by hand
  # (console, `update!(slug: ...)`) keeps the old URL resolving; EpisodesController#show
  # 301s old slugs and numeric ids to the current one. Numeric ids are still accepted by
  # Episode.friendly.find, and #to_param falls back to the id while a row has no slug.
  friendly_id :slug_source, use: [:slugged, :history]
  include SequencedSlug

  belongs_to :season
  belongs_to :location, optional: true   # ← allow nil for Solo

  has_many :appearances, dependent: :destroy
  accepts_nested_attributes_for :appearances, allow_destroy: true,
    reject_if: proc { |attrs| attrs['survivor_id'].blank? }
  has_many :appearance_items, through: :appearances
  has_many :survivors, through: :appearances
  has_many :episode_traps, dependent: :destroy
  accepts_nested_attributes_for :episode_traps, allow_destroy: true,
    reject_if: proc { |attrs| attrs['trap_type'].blank? }
  has_many :episode_shelters, dependent: :destroy
  accepts_nested_attributes_for :episode_shelters, allow_destroy: true,
    reject_if: proc { |attrs| attrs['shelter_type'].blank? }
  has_many :food_sources, dependent: :destroy
  accepts_nested_attributes_for :food_sources, allow_destroy: true,
    reject_if: proc { |attrs| attrs['name'].blank? }

  has_many :medical_calls, dependent: :destroy
  accepts_nested_attributes_for :medical_calls, allow_destroy: true,
    reject_if: proc { |attrs| attrs['survivor_id'].blank? && attrs['reason'].blank? }

  has_many :bushcraft_items, dependent: :destroy
  accepts_nested_attributes_for :bushcraft_items, allow_destroy: true,
    reject_if: proc { |attrs| attrs['item_type'].blank? }

  validates :title, :number_in_season, presence: true

  # HOW MANY TEAMS? There is no survivor-to-team data, so it comes from the free-text
  # participant_arrangement: split on "+" and count the parts that are positive whole
  # numbers. "3+3+3+3" = 4 teams, "3+2" = 2, "3+3+3+3+1" = 5, "2+2+2+2+2+2+2" = 7.
  # A single number ("3", "4"), a word ("Standard", "Group", "Trio", "Solo") or nothing
  # at all is one team. A team-given item counts once per team (AppearanceItem.counted).
  def self.team_count_for(arrangement)
    teams = arrangement.to_s.split("+").count { |part| (n = part.strip).match?(/\A[0-9]+\z/) && !n.match?(/\A0+\z/) }
    [teams, 1].max
  end

  # The same rule as team_count_for, as SQL, so counting queries agree with the Ruby.
  # alias_name is the episodes table (or alias) in the query. Keep the two in step;
  # the model test checks them against each other.
  def self.team_count_sql(alias_name = "episodes")
    <<~SQL.squish
      GREATEST(1, (SELECT COUNT(*) FROM regexp_split_to_table(COALESCE(#{alias_name}.participant_arrangement, ''), '[+]') AS tc_part
                    WHERE btrim(tc_part) ~ '^[0-9]+$' AND btrim(tc_part) !~ '^0+$'))
    SQL
  end

  # Arrangement words that mean "one team" without any numbers to parse.
  SINGLE_TEAM_WORDS = %w[standard trio solo].freeze

  def team_count = self.class.team_count_for(participant_arrangement)
  def multi_team? = team_count > 1

  # False when the arrangement tells us nothing about teams (blank, "Group", free text),
  # so team_count is just the default of 1 and a human should check 2+ survivor episodes.
  def team_count_known?
    arr = participant_arrangement.to_s.strip
    arr.split("+").any? { |part| part.strip.match?(/\A[0-9]+\z/) && !part.strip.match?(/\A0+\z/) } || SINGLE_TEAM_WORDS.include?(arr.downcase)
  end

  # Optional: enforce location for non-Solo series only
  validate :location_required_unless_solo

  SLUG_TITLE_MAX = 60

  # The text the slug is made from: "Naked and Afraid XL" + S4 + E1 + the title ->
  # "naked-and-afraid-xl-s4e1-<title words, at most 60 characters>".
  def slug_source
    series = season&.series&.name.to_s.parameterize
    code   = [season&.number && "s#{season.number}", number_in_season && "e#{number_in_season}"].compact.join
    parts  = [series, code, self.class.slug_title_words(title)].reject(&:blank?)
    parts.join("-").presence || "episode"
  end

  # Generate a slug only while there is none (frozen afterwards, see above).
  def should_generate_new_friendly_id?
    slug.blank?
  end

  # The title as hyphenated words, cut at a word boundary to keep URLs short.
  def self.slug_title_words(title, max: SLUG_TITLE_MAX)
    words = title.to_s.parameterize.split("-")
    kept  = []
    words.each do |word|
      break if (kept + [word]).join("-").length > max && kept.any?
      kept << word
    end
    kept.join("-")[0, max].to_s.sub(/-+\z/, "")
  end

  private
  def location_required_unless_solo
    return if location_id.present?
    return if season&.series&.name&.strip&.downcase == "naked and afraid: solo"
    errors.add(:location, "must exist")
  end
end