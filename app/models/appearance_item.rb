# app/models/appearance_item.rb
#
# One row links one survivor's appearance in an episode to one item.
#
# GIVEN ITEMS AND COUNTING
# The show usually gives ONE item to the whole team, but we store a row per
# survivor so each survivor's page still shows what they had access to. That
# makes the raw rows a poor thing to count. `given_scope` says which case a given
# row is:
#
#   "team"        one item for the whole team: all survivors' rows describe the
#                 same physical item and it must count ONCE per episode
#   "individual"  one item per person: every row is a real, separate item
#   nil           not a given item (brought/found/...), or a given row from before
#                 the column existed that nobody has classified yet; counts per
#                 row, as it always did. New given rows default to "team".
#
# Anything that counts or ranks appearance_items by how often they appeared
# should go through `counted` (or `item_totals` / `given_count`) so there is one
# definition of "how many". Per-survivor displays (a survivor's own page) should
# NOT use it: they list every row.
class AppearanceItem < ApplicationRecord
  has_paper_trail
  belongs_to :appearance
  belongs_to :item

  GIVEN_SCOPES        = %w[team individual].freeze
  DEFAULT_GIVEN_SCOPE = "team".freeze # "usually it's given to the team"

  scope :brought, -> { where(source: "brought") }
  scope :given,   -> { where(source: "given") }
  scope :given_to_team, -> { where(source: "given", given_scope: "team") }

  enum :source, {
    brought: "brought",
    given:   "given",
    found:   "found",
    earned:  "earned",
    foraged: "foraged"
  }, prefix: true

  before_validation :normalize_given_scope

  validates :quantity, numericality: { greater_than: 0 }
  validates :source, presence: true
  validates :given_scope, inclusion: { in: GIVEN_SCOPES }, allow_nil: true
  validate  :given_scope_only_on_given_items

  # For every team-given (episode, item, subtype), the ONE row that stands for it:
  # the row with the highest quantity (ties: lowest id). Team rows for the same
  # episode/item/subtype are copies of one physical item, so quantity is "how many
  # the team got", not a per-person figure to add up.
  TEAM_GIVEN_REPRESENTATIVES_SQL = <<~SQL.squish.freeze
    SELECT DISTINCT ON (tg_app.episode_id, tg_ai.item_id, COALESCE(tg_ai.subtype, ''))
           tg_ai.id
      FROM appearance_items tg_ai
      JOIN appearances tg_app ON tg_app.id = tg_ai.appearance_id
     WHERE tg_ai.source = 'given' AND tg_ai.given_scope = 'team'
     ORDER BY tg_app.episode_id, tg_ai.item_id, COALESCE(tg_ai.subtype, ''),
              tg_ai.quantity DESC, tg_ai.id
  SQL

  # THE counting rule. Narrows any appearance_items relation to the rows that
  # should be counted: every brought/found/... row, every individual (or
  # unclassified) given row, and ONE row per team-given (episode, item, subtype).
  # Chain it before COUNT / SUM(quantity); filters on episode, item, country, etc.
  # compose normally because the representative is chosen per episode and item.
  #
  # Do not combine it with a filter on one survivor: a survivor's own rows are
  # all "theirs", and the representative might be a teammate's row.
  scope :counted, lambda {
    where(<<~SQL.squish)
      appearance_items.source <> 'given'
      OR appearance_items.given_scope IS DISTINCT FROM 'team'
      OR appearance_items.id IN (#{TEAM_GIVEN_REPRESENTATIVES_SQL})
    SQL
  }

  # How many of this source were there? (Sum of quantities, team items once.)
  def self.counted_quantity
    counted.sum(:quantity)
  end

  # Given items, team-given counted once per episode. Works on any relation:
  #   AppearanceItem.given_count
  #   AppearanceItem.where(item_id: 7).given_count
  #   episode.appearance_items.given_count
  def self.given_count
    given.counted.sum(:quantity)
  end

  # Relation of items ranked by how often they appeared from one source, for the
  # "Top brought / Top given" tables. Each row responds to id, name and total.
  def self.item_totals(source)
    where(source: source).counted.joins(:item)
      .group("items.id", "items.name")
      .select("items.id, items.name, SUM(appearance_items.quantity) AS total")
      .order("total DESC, items.name ASC")
  end

  def given_to_team?
    source_given? && given_scope == "team"
  end

  # Display name: prefers a specific subtype (e.g. "elk hide") over the generic
  # item name ("hide"). Falls back to the item's name when no subtype set.
  def display_name
    s = subtype.to_s.strip
    s.empty? ? item&.name : s
  end

  # One entry on the "Team given" banner of an episode page.
  TeamGivenGroup = Struct.new(:appearance_item, :recipients, :everyone, keyword_init: true) do
    def quantity = appearance_item.quantity.to_i
  end

  # Splits an episode's given items into what belongs on a single "Team given"
  # banner and what stays in each survivor's row. appearances: Appearance records
  # with appearance_items (and their survivors) loaded.
  #
  #   -> { groups: [TeamGivenGroup], hoisted_ids: Set of appearance_item ids that
  #        the banner already covers, so the per-survivor column should skip them }
  #
  # Team-scoped rows are grouped by (item, subtype), one banner entry each. Rows
  # nobody has classified yet follow the old rule: if every survivor has the exact
  # same set of given items, it is a team item and gets hoisted too (only when the
  # episode has no classified given rows, so a deliberate "individual" is never
  # swallowed by the heuristic).
  def self.team_given_banner(appearances)
    appearances = Array(appearances)
    given = appearances.flat_map { |a| a.appearance_items.select(&:source_given?).map { |ai| [a, ai] } }
    groups = []
    hoisted = Set.new

    team_rows = given.select { |_, ai| ai.given_scope == "team" }
    team_rows.group_by { |_, ai| [ai.item_id, ai.subtype.to_s.strip] }.each_value do |rows|
      rep = rows.map(&:last).max_by { |ai| [ai.quantity.to_i, -ai.id.to_i] }
      names = rows.map { |a, _| a.survivor&.full_name }.compact.uniq
      groups << TeamGivenGroup.new(appearance_item: rep, recipients: names,
                                   everyone: rows.map { |a, _| a.id }.uniq.size == appearances.size)
      rows.each { |_, ai| hoisted << ai.id }
    end

    if given.any? && given.all? { |_, ai| ai.given_scope.nil? }
      signatures = appearances.map do |a|
        a.appearance_items.select(&:source_given?).map { |ai| [ai.item_id, ai.subtype.to_s.strip, ai.quantity.to_i] }.sort
      end
      if signatures.uniq.size == 1
        first = appearances.first.appearance_items.select(&:source_given?)
        first.each do |ai|
          groups << TeamGivenGroup.new(appearance_item: ai, recipients: appearances.filter_map { |a| a.survivor&.full_name }, everyone: true)
        end
        given.each { |_, ai| hoisted << ai.id }
      end
    end

    { groups: groups, hoisted_ids: hoisted }
  end

  private

  # "Usually it's given to the team", so a NEW given row (or a row that has just become
  # given) with no scope is team. An existing given row that predates the column keeps
  # nil ("not classified yet") until someone picks a scope or the backfill runs, so merely
  # re-saving it never decides for you. A row that stops being "given" loses a scope it
  # carried over from when it was; blank strings from forms are nil.
  def normalize_given_scope
    self.given_scope = given_scope.presence
    if source_given?
      self.given_scope ||= DEFAULT_GIVEN_SCOPE if new_record? || will_save_change_to_source?
    elsif will_save_change_to_source? && !will_save_change_to_given_scope?
      self.given_scope = nil
    end
  end

  def given_scope_only_on_given_items
    errors.add(:given_scope, "only applies to given items") if given_scope.present? && !source_given?
  end
end
