# The shop cards for one episode or survivor page: for each item that appears there,
# the catalog products for that item. Products that name this survivor (or this episode)
# come first, then the strongest matches, and each item is capped so a popular item
# like "knife" doesn't swamp the page.
class ShopShelf
  Entry = Struct.new(:product, :label, keyword_init: true)
  Group = Struct.new(:item, :entries, :total, keyword_init: true) do
    def hidden = total - entries.size
  end

  # holders: { Item => [full names of the survivors who had it here] }
  # episode: the Episode being shown, if any (products can name specific episodes)
  def self.build(holders:, episode: nil, limit: 4) = new(holders, episode, limit)

  attr_reader :groups

  def initialize(holders, episode, limit)
    @episode_key = episode_key(episode)
    @groups = holders.sort_by { |item, _| item.name.to_s.downcase }.filter_map do |item, names|
      products = ShopCatalog.for_item(item.name)
      next if products.empty?
      entries = products.each_with_index.map { |p, i| [entry(p, names), i] }
                        .sort_by { |e, i| [e.label ? 0 : 1, i] }
                        .first(limit).map(&:first)
      Group.new(item: item, entries: entries, total: products.size)
    end
  end

  def empty? = groups.empty?
  def products = groups.flat_map { |g| g.entries.map(&:product) }

  private

  def entry(product, names)
    Entry.new(product: product, label: label_for(product, names))
  end

  def label_for(product, names)
    return "Seen in this episode" if @episode_key && Array(product[:episodes]).any? { |e| key_of(e) == @episode_key }
    wanted = names.map { |n| n.to_s.downcase }
    match  = Array(product[:survivors]).find { |n| wanted.include?(n.to_s.downcase) }
    match && "Used by #{match}"
  end

  def episode_key(episode)
    return unless episode&.season
    [episode.season.series&.name.to_s, episode.season.number.to_i, episode.title.to_s.downcase]
  end

  def key_of(e) = [e[:series].to_s, e[:season].to_i, e[:title].to_s.downcase]
end
