# Builds the "Shop the gear" shelf for a page from the gear brought or given in a set of
# episodes (a country, a location, a season, an item type, one episode). The block narrows
# an AppearanceItem scope that is already joined to item, appearance, survivor and the
# episode's location.
module GearShelf
  extend ActiveSupport::Concern

  # The season's id when it is a continuous-story one (its episodes are one story), else NULL.
  CONTINUOUS_SEASON_ID_SQL = <<~SQL.squish.freeze
    (SELECT CASE WHEN COALESCE(gs.continuous_story, FALSE) OR COALESCE(gsr.continuous_story, FALSE) THEN gs.id END
       FROM seasons gs LEFT JOIN series gsr ON gsr.id = gs.series_id
      WHERE gs.id = episodes.season_id)
  SQL

  private

  # Distinct (item, survivor) pairs, so a survivor carried across the episodes of a
  # continuous-story season counts once. Busiest items first, where "busy" counts a
  # team-given item once per TEAM (one pot handed to each of two teams is two pots, not
  # four holders; capped at the survivors who carry it; once per continuous season there)
  # and everything else once per survivor.
  def build_gear_shelf(label:, episodes: [], max_groups: 8, limit: 3, matches: nil, amazon_only: false, available_only: false)
    scope = AppearanceItem.where(source: %w[brought given])
                          .joins(:item, appearance: [:survivor, { episode: :location }])
    rows = yield(scope).distinct.pluck(:item_id, "survivors.full_name", "appearance_items.given_scope",
                                       "appearances.episode_id", Arel.sql(CONTINUOUS_SEASON_ID_SQL),
                                       Arel.sql(Episode.team_count_sql("episodes")))

    items   = Item.where(id: rows.map(&:first).uniq).index_by(&:id)
    by_item = rows.group_by(&:first)
    holders = by_item.to_h { |id, rs| [items[id], rs.map { |r| r[1] }.uniq] }
    rank    = by_item.to_h do |id, rs|
      people = rs.reject { |r| r[2] == "team" }.map { |r| r[1] }.uniq.size
      # one group per episode (per season when continuous); worth its teams, capped at its survivors
      teams = rs.select { |r| r[2] == "team" }
                .group_by { |_id, _name, _scope, episode_id, season_id, _teams| season_id ? "season-#{season_id}" : "episode-#{episode_id}" }
                .sum { |_key, grp| [grp.map { |r| r[5].to_i }.max, grp.map { |r| r[1] }.uniq.size].min }
      [items[id], people + teams]
    end

    @shop_shelf = ShopShelf.build(holders: holders, episodes: episodes, episode_label: label,
                                  rank: rank, max_groups: max_groups, limit: limit, matches: matches, amazon_only: amazon_only, available_only: available_only)
    @shop_links = ShopLinks.build(@shop_shelf.products)
  end
end
