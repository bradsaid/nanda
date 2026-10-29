# Builds the "Shop the gear" shelf for a page from the gear brought or given in a set of
# episodes (a country, a location, a season, an item type, one episode). The block narrows
# an AppearanceItem scope that is already joined to item, appearance, survivor and the
# episode's location.
module GearShelf
  extend ActiveSupport::Concern

  private

  # Distinct (item, survivor) pairs, so a survivor carried across the episodes of a
  # continuous-story season counts once. Busiest items first.
  def build_gear_shelf(label:, episodes: [], max_groups: 8, limit: 3, matches: nil)
    scope = AppearanceItem.where(source: %w[brought given])
                          .joins(:item, appearance: [:survivor, { episode: :location }])
    pairs   = yield(scope).distinct.pluck(:item_id, "survivors.full_name")
    items   = Item.where(id: pairs.map(&:first).uniq).index_by(&:id)
    holders = pairs.group_by(&:first).to_h { |id, rows| [items[id], rows.map(&:last).uniq] }
    @shop_shelf = ShopShelf.build(holders: holders, episodes: episodes, episode_label: label,
                                  rank: holders.transform_values(&:size), max_groups: max_groups, limit: limit, matches: matches)
    @shop_links = ShopLinks.build(@shop_shelf.products)
  end
end
