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
  # continuous-story season counts once. Busiest items first, where "busy" counts each
  # team-given item ONCE per episode (one pot handed to a team of two is one pot, not
  # two holders; once per continuous season there) and everything else once per survivor.
  def build_gear_shelf(label:, episodes: [], max_groups: 8, limit: 3, matches: nil, amazon_only: false, available_only: false)
    scope = AppearanceItem.where(source: %w[brought given])
                          .joins(:item, appearance: [:survivor, { episode: :location }])
    rows = yield(scope).distinct.pluck(:item_id, "survivors.full_name", "appearance_items.given_scope",
                                       "appearances.episode_id", Arel.sql(CONTINUOUS_SEASON_ID_SQL))

    items   = Item.where(id: rows.map(&:first).uniq).index_by(&:id)
    by_item = rows.group_by(&:first)
    holders = by_item.to_h { |id, rs| [items[id], rs.map { |r| r[1] }.uniq] }
    rank    = by_item.to_h do |id, rs|
      units = rs.map do |_id, name, given_scope, episode_id, season_id|
        given_scope == "team" ? [:team, season_id ? "season-#{season_id}" : "episode-#{episode_id}"] : [:person, name]
      end
      [items[id], units.uniq.size]
    end

    @shop_shelf = ShopShelf.build(holders: holders, episodes: episodes, episode_label: label,
                                  rank: rank, max_groups: max_groups, limit: limit, matches: matches, amazon_only: amazon_only, available_only: available_only)
    @shop_links = ShopLinks.build(@shop_shelf.products)
  end
end
