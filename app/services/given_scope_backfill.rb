# Classifies existing "given" appearance_items as team or individual (given_scope).
#
# Run it through `rake appearance_items:backfill_given_scope` (dry run unless WRITE=1).
# Only rows whose given_scope is still NULL are looked at, so it is idempotent and
# never overwrites a scope someone chose by hand.
#
# Heuristic, per episode and per given item (item_id + subtype):
#
#   solo episode (one survivor)            -> team   (team and individual are the
#                                                     same thing; counts once either way)
#   on EVERY survivor, quantity 1 each     -> team   (one item handed to the team, a
#                                                     row recorded for each member)
#   on EVERY survivor, quantity > 1 / mixed-> individual, REVIEW (two pots for the
#                                                     team, or one each of two things?)
#   on one survivor of three or more       -> individual (that survivor's own item; one
#                                                     row counts once either way)
#   on only SOME survivors (2+, or 1 of 2) -> individual, REVIEW (item for one of two
#                                                     survivors? or one team of a
#                                                     multi-team episode? or a data gap?)
#
# Counting afterwards (AppearanceItem.counted): a team group is worth one item per TEAM
# (Episode#team_count, read from the participant_arrangement: "3+3+3+3" = 4 pots),
# capped at the survivors who carry it; an individual group is worth the sum of its rows.
# Extra review flags for that rule: in a multi-team episode every team should have got a
# team item, so an item on only some survivors is flagged (even one survivor of many), and
# episodes whose arrangement says nothing about teams but that have 2+ survivors are listed.
#
# "Individual" is the conservative answer: it keeps today's per-row counting, so a wrong
# guess here can only leave the old overcount in place, never hide a real item.
class GivenScopeBackfill
  Group = Struct.new(:episode_id, :item_id, :subtype, :row_ids, :quantities, :survivors, :appearances,
                     :teams, :scope, :reason, :review, keyword_init: true) do
    def rows = row_ids.size

    # What the group counts for under the rule (see AppearanceItem::TEAM_GIVEN_UNITS_SQL).
    def counted_units
      scope == "team" ? [teams, rows].min * quantities.max : quantities.sum
    end

    # What the old once-per-episode rule would have counted, for the before/after report.
    def once_per_episode_units
      scope == "team" ? quantities.max : quantities.sum
    end
  end

  attr_reader :groups

  def initialize(relation = AppearanceItem.given.where(given_scope: nil))
    @relation = relation
  end

  # Builds the decisions without touching the database.
  def classify
    appearance_counts = Appearance.group(:episode_id).count
    rows = @relation.joins(:appearance)
                    .pluck("appearances.episode_id", :item_id, :subtype, :id, :quantity, "appearances.survivor_id", :appearance_id)
    @team_counts = Episode.where(id: rows.map(&:first).uniq).pluck(:id, :participant_arrangement)
                          .to_h { |id, arrangement| [id, Episode.team_count_for(arrangement)] }

    @groups = rows.group_by { |ep, item, subtype, *| [ep, item, subtype.to_s.strip] }.map do |(ep, item, subtype), rs|
      n = appearance_counts[ep].to_i
      g = Group.new(episode_id: ep, item_id: item, subtype: subtype, row_ids: rs.map { |r| r[3] },
                    quantities: rs.map { |r| r[4].to_i }, survivors: n, appearances: rs.map { |r| r[6] }.uniq.size,
                    teams: @team_counts.fetch(ep, 1))
      decide(g)
      g
    end
    self
  end

  # Writes the decisions. update_all on purpose: ~a thousand rows would otherwise flood
  # the admin changelog (it only shows the latest 300 versions) with one audit entry
  # each. updated_at IS bumped, because the /items page cache is keyed on it.
  def apply!
    classify unless groups
    now = Time.current
    AppearanceItem.transaction do
      groups.group_by(&:scope).each do |scope, gs|
        AppearanceItem.where(id: gs.flat_map(&:row_ids), given_scope: nil)
                      .update_all(given_scope: scope, updated_at: now)
      end
    end
  end

  # ---------- reporting ----------

  def episode_labels
    @episode_labels ||= Episode.includes(season: :series)
                               .where(id: groups.map(&:episode_id).uniq).index_by(&:id)
  end

  # { "arrangement" => { team: n, individual: n, review: n, rows: n, teams: n, counted: n } }
  def summary_by_type
    groups.group_by { |g| arrangement_for(g.episode_id) }.transform_values do |gs|
      { team: gs.count { |g| g.scope == "team" }, individual: gs.count { |g| g.scope == "individual" },
        review: gs.count(&:review), rows: gs.sum(&:rows), teams: gs.map(&:teams).max, counted: gs.sum(&:counted_units) }
    end.sort_by { |type, _| type }.to_h
  end

  def review_groups = groups.select(&:review)

  # Given "units" three ways: raw rows (what a naive SUM sees today), the earlier
  # once-per-episode rule, and the per-team rule that is in force.
  def totals
    {
      groups:            groups.size,
      rows:              groups.sum(&:rows),
      team_groups:       groups.count { |g| g.scope == "team" },
      individual_groups: groups.count { |g| g.scope == "individual" },
      units_before:      groups.sum { |g| g.quantities.sum },
      units_once_per_episode: groups.sum(&:once_per_episode_units),
      units_after:       groups.sum(&:counted_units),
      episodes:          groups.map(&:episode_id).uniq.size
    }
  end

  # { item_id => { rows:, once_per_episode:, per_team: } } for the report's per-item lines.
  def totals_by_item
    groups.group_by(&:item_id).transform_values do |gs|
      { rows: gs.sum { |g| g.quantities.sum }, once_per_episode: gs.sum(&:once_per_episode_units), per_team: gs.sum(&:counted_units) }
    end
  end

  # Episodes whose arrangement says nothing about teams (blank, "Group", free text) but
  # that have 2+ survivors: team_count fell back to 1, which may undercount.
  def unparseable_arrangement_episodes
    ids = groups.select { |g| g.survivors >= 2 }.map(&:episode_id).uniq
    episode_labels.values_at(*ids).compact.reject(&:team_count_known?).sort_by(&:id)
  end

  def arrangement_for(episode_id)
    ep = episode_labels[episode_id]
    ep&.participant_arrangement.presence || "(none)"
  end

  def episode_label(episode_id)
    ep = episode_labels[episode_id]
    return "episode ##{episode_id}" unless ep
    "#{ep.season&.series&.name} S#{ep.season&.number} E#{ep.number_in_season} #{ep.title}".squish
  end

  private

  def decide(g)
    multi = g.teams > 1
    partial_note = multi ? "each of the #{g.teams} teams should have got it, but " : ""
    if g.survivors <= 1
      g.scope, g.reason, g.review = "team", "solo episode (team and individual are equivalent)", false
    elsif g.appearances >= g.survivors
      if g.quantities.uniq == [1]
        g.scope, g.reason, g.review = "team", "on all #{g.survivors} survivors, quantity 1 each", false
        if g.teams > g.appearances
          g.review = true
          g.reason += "; arrangement says #{g.teams} teams but only #{g.appearances} survivors, counted #{g.appearances}"
        end
      else
        g.scope, g.reason, g.review = "individual", "on all #{g.survivors} survivors but quantity #{g.quantities.sort.join('/')} (team got several? or one each?)", true
      end
    elsif g.appearances == 1 && g.survivors > 2 && !multi
      # One recipient out of several: that survivor's own item. One row counts once
      # whether it is called team or individual, so there is nothing to review.
      g.scope, g.reason, g.review = "individual", "single recipient (1 of #{g.survivors} survivors)", false
    else
      g.scope, g.reason, g.review = "individual", "#{partial_note}only #{g.appearances} of #{g.survivors} survivors have it", true
    end
  end
end
