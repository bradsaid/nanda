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

  # Stable id for a product's card on the Shop page, so other pages can link straight to it.
  def self.anchor(product)
    "p-" + [product[:item], product[:brand], product[:product]].join(" ").parameterize
  end

  # [series name, season number, lowercase title] for an Episode, or nil.
  def self.episode_key(episode)
    return unless episode&.season
    [episode.season.series&.name.to_s, episode.season.number.to_i, episode.title.to_s.downcase]
  end

  # The catalog product documented for this survivor and item (the card to link a table
  # row to), or nil. Prefers a product that also names this episode, then the strongest match.
  def self.specific_for(item_name, survivor_name, episode: nil)
    wanted = survivor_name.to_s.downcase
    return if wanted.blank?
    mine = for_item(item_name).select { |p| Array(p[:survivors]).any? { |n| n.to_s.downcase == wanted } }
    return mine.first if mine.size < 2 || episode.nil?
    key = episode_key(episode)
    mine.find { |p| Array(p[:episodes]).any? { |e| [e[:series].to_s, e[:season].to_i, e[:title].to_s.downcase] == key } } || mine.first
  end

  # "knifecenter.com (listed as discontinued)" -> button "knifecenter.com", caption "listed as discontinued".
  def self.store_name(link)
    name = link[:store].to_s.sub(/\s*\(.*\)\s*\z/m, "").strip
    name.include?(".") ? name : name.upcase_first
  end

  def self.store_note(link) = link[:store].to_s[/\((.*)\)\s*\z/m, 1].to_s.strip.presence

  def self.amazon?(link)
    link[:store].to_s == "amazon" || link[:url].to_s.match?(AMAZON)
  end

  def self.amazon_link(product)
    Array(product[:buy]).find { |l| amazon?(l) }
  end

  # Any amazon.com address (www or bare, http or https).
  AMAZON_ANY = %r{\Ahttps?://(www\.)?amazon\.com(/|\?|\z)}i

  def self.amazon_url?(url) = url.to_s.match?(AMAZON_ANY)

  # Adds our Amazon Associates tag to an amazon.com URL once one is configured.
  # Other hosts (and links that already carry a tag) come back unchanged.
  def self.tagged_url(url, tag: ENV["AMAZON_ASSOCIATE_TAG"])
    url = url.to_s
    return url if tag.blank? || !amazon_url?(url) || url.match?(/[?&]tag=/)

    url + (url.include?("?") ? "&" : "?") + "tag=#{CGI.escape(tag)}"
  end

  def self.buy_url(link, tag: ENV["AMAZON_ASSOCIATE_TAG"])
    tagged_url(link[:url], tag: tag)
  end

  # Amazon links inside stored HTML (survivor bios): tag them and mark them sponsored.
  def self.tag_html_links(html, tag: ENV["AMAZON_ASSOCIATE_TAG"])
    return html if html.blank? || !html.include?("amazon.com")

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    fragment.css("a[href]").each do |a|
      next unless amazon_url?(a["href"])
      a["href"] = tagged_url(a["href"], tag: tag)
      a["rel"]  = "sponsored noopener noreferrer nofollow"
    end
    fragment.to_html
  end
end
