# app/models/episode.rb
class Episode < ApplicationRecord
  has_paper_trail
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

  private
  def location_required_unless_solo
    return if location_id.present?
    return if season&.series&.name&.strip&.downcase == "naked and afraid: solo"
    errors.add(:location, "must exist")
  end
end