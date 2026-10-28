# Read-only catalog of purchasable gear tied to Naked and Afraid, loaded from
# config/shop_products.yml. Plain data on purpose: it is edited by hand and
# diffed in git, and needs no migration.
class ShopCatalog
  PATH   = Rails.root.join("config/shop_products.yml")
  MATCHES = %w[confirmed likely similar].freeze # strongest evidence first
  AMAZON  = %r{\Ahttps://www\.amazon\.com/}
  # Books, DVDs and merch were not used on the show, so they sort after the gear.
  NON_GEAR = %w[merch media].freeze

  def self.products
    @products = nil if Rails.env.development? # pick up edits without a restart
    @products ||= (YAML.safe_load_file(PATH) || []).map { |h| h.with_indifferent_access.freeze }.freeze
  end

  BADGES = {
    "confirmed" => ["bg-success", "Confirmed on the show"],
    "likely"    => ["bg-primary", "Likely match"],
    "similar"   => ["bg-secondary", "Similar"]
  }.freeze

  # Products that map to one Item (by its name), strongest evidence first.
  def self.for_item(name)
    rank = MATCHES.each_with_index.to_h
    products.select { |p| p[:item].to_s.casecmp?(name.to_s) }
            .sort_by { |p| [rank.fetch(p[:match], 99), p[:product].to_s.downcase] }
  end

  def self.amazon?(link)
    link[:store].to_s == "amazon" || link[:url].to_s.match?(AMAZON)
  end

  def self.amazon_link(product)
    Array(product[:buy]).find { |l| amazon?(l) }
  end

  # Adds our Amazon Associates tag to amazon.com links once one is configured.
  def self.buy_url(link, tag: ENV["AMAZON_ASSOCIATE_TAG"])
    url = link[:url].to_s
    return url if tag.blank? || !url.match?(AMAZON)

    url + (url.include?("?") ? "&" : "?") + "tag=#{CGI.escape(tag)}"
  end
end
