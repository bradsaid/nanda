# The shop cards for one episode, survivor, or country page: for each item that appears
# there, the catalog products for that item. Products that name this survivor (or one of
# these episodes) come first, then the strongest matches, and each item is capped so a
# popular item like "knife" doesn't swamp the page.
class ShopShelf
  Entry = Struct.new(:product, :label, keyword_init: true)
  Group = Struct.new(:item, :entries, :total, keyword_init: true) do
    def hidden = total - entries.size
  end

  # holders:       { Item => [full names of the survivors who had it here] }
  # episode(s):    the Episode(s) being shown; products can name specific episodes
  # episode_label: badge text for a product that names one of those episodes
  # rank:          { Item => number } to list the busiest items first (default: A to Z)
  # max_groups:    show at most this many items (default: all)
  # only_named:    true = keep only products that name one of the holders (a survivor's
  #                own page must not show gear documented for other survivors)
  # matches:       keep only products at these match levels, e.g. %w[confirmed]
  def self.build(holders:, episode: nil, episodes: nil, episode_label: "Seen in this episode",
                 rank: nil, max_groups: nil, limit: 4, only_named: false, matches: nil)
    new(holders, Array(episodes || episode).compact, episode_label, rank, max_groups, limit, only_named, matches)
  end

  attr_reader :groups

  def initialize(holders, episodes, episode_label, rank, max_groups, limit, only_named = false, matches = nil)
    @episode_keys  = episodes.filter_map { |e| episode_key(e) }.to_set
    @episode_label = episode_label
    ordered = holders.sort_by do |item, _|
      [rank ? -rank.fetch(item, 0) : 0, item.name.to_s.downcase]
    end
    @groups = ordered.filter_map do |item, names|
      products = ShopCatalog.for_item(item.name)
      products = products.select { |p| names_holder?(p, names) } if only_named
      products = products.select { |p| matches.include?(p[:match]) } if matches
      next if products.empty?
      entries = products.each_with_index.map { |p, i| [entry(p, names), i] }
                        .sort_by { |e, i| [e.label ? 0 : 1, i] }
                        .first(limit).map(&:first)
      Group.new(item: item, entries: entries, total: products.size)
    end
    @hidden_groups = max_groups ? [@groups.size - max_groups, 0].max : 0
    @groups = @groups.first(max_groups) if max_groups
  end

  # Items that have products but were left off by max_groups.
  attr_reader :hidden_groups

  def empty? = groups.empty?

  # Is this product's card on the page this shelf renders?
  def include?(product)
    @anchors ||= products.map { |p| ShopCatalog.anchor(p) }.to_set
    @anchors.include?(ShopCatalog.anchor(product))
  end
  def products = groups.flat_map { |g| g.entries.map(&:product) }

  private

  def entry(product, names)
    Entry.new(product: product, label: label_for(product, names))
  end

  def names_holder?(product, names)
    wanted = names.map { |n| n.to_s.downcase }
    Array(product[:survivors]).any? { |n| wanted.include?(n.to_s.downcase) }
  end

  def label_for(product, names)
    if @episode_keys.any? && Array(product[:episodes]).any? { |e| @episode_keys.include?(key_of(e)) }
      return @episode_label
    end
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
