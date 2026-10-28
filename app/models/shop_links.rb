# Resolves the survivors and episodes a catalog product names into real records, so shop
# cards can link to the site's own bio and episode pages. Two queries for a whole page of
# products. Anything that no longer exists (renamed survivor, retitled episode) is simply
# not linked.
class ShopLinks
  def self.build(products) = new(products)

  def initialize(products)
    @survivor_names = products.flat_map { |p| Array(p[:survivors]) }.uniq
    @episode_keys   = products.flat_map { |p| episode_keys(p) }.uniq
    @survivors = load_survivors
    @episodes  = load_episodes
  end

  def survivors_for(product)
    Array(product[:survivors]).filter_map { |n| @survivors[n.to_s.downcase] }
  end

  def episodes_for(product)
    episode_keys(product).filter_map { |k| @episodes[k] }
  end

  private

  def episode_keys(product)
    Array(product[:episodes]).map { |e| [e[:series].to_s, e[:season].to_i, e[:title].to_s.downcase] }
  end

  def load_survivors
    return {} if @survivor_names.empty?
    Survivor.where(full_name: @survivor_names).index_by { |s| s.full_name.downcase }
  end

  def load_episodes
    return {} if @episode_keys.empty?
    Episode.joins(season: :series).includes(season: :series)
           .where(series: { name: @episode_keys.map(&:first).uniq },
                  seasons: { number: @episode_keys.map { |k| k[1] }.uniq })
           .index_by { |e| [e.season.series.name, e.season.number, e.title.downcase] }
           .slice(*@episode_keys)
  end
end
