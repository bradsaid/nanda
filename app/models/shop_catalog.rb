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

  # { "knife" => 12, ... } how many products each item has (lowercase item names).
  def self.item_counts = products.group_by { |p| p[:item].to_s.downcase }.transform_values(&:size)

  # { "eva rupert" => 3, ... } how many products name each survivor (lowercase names).
  def self.survivor_counts
    products.each_with_object(Hash.new(0)) { |p, h| Array(p[:survivors]).each { |n| h[n.to_s.downcase] += 1 } }
  end

  # Products documented for one survivor, strongest evidence first.
  def self.for_survivor(name)
    rank = MATCHES.each_with_index.to_h
    wanted = name.to_s.downcase
    products.select { |p| Array(p[:survivors]).any? { |n| n.to_s.downcase == wanted } }
            .sort_by { |p| [rank.fetch(p[:match], 99), p[:product].to_s.downcase] }
  end

  # Catalog item names mentioned in free text (a forum thread), most-mentioned first.
  # Whole words only, and a plural ("knives" aside) counts: "knifes", "pots", "bowls".
  def self.mentioned_in(text)
    haystack = text.to_s.downcase
    return [] if haystack.blank?
    products.map { |p| p[:item].to_s.downcase }.reject(&:blank?).uniq.filter_map do |name|
      n = haystack.scan(/(?<![[:alnum:]])#{Regexp.escape(name)}(?:s|es)?(?![[:alnum:]])/).size
      [name, n] if n.positive?
    end.sort_by { |name, n| [-n, name] }.map(&:first)
  end

  # ---- Gear guides: one landing page per catalog category --------------------------

  Guide = Struct.new(:slug, :category, :title, :heading, :description, :intro, keyword_init: true)

  GUIDE_COPY = {
    "blade"              => ["Knives, Machetes & Blades", "Every blade, machete and knife we could tie to the show, from the cast's own makers to the closest buyable stand-ins.", "A blade is the single most-brought item on Naked and Afraid. Here is every machete, knife and kukri we have matched to a survivalist or an episode."],
    "fire starting tool" => ["Fire Starters", "Ferro rods, strikers and fire kits used on Naked and Afraid, and the nearest products you can buy.", "Fire is the first job on day one. These are the ferro rods and fire kits survivalists brought to the challenge."],
    "fishing tool"       => ["Fishing Gear", "Hooks, line, nets and spears used on Naked and Afraid, with where each was spotted.", "Hooks, line, gill nets and spears: the gear survivalists use to feed themselves."],
    "hunting weapon"     => ["Hunting Weapons & Tools", "Bows, spears, slings and throwing tools used on Naked and Afraid, with the closest products you can buy.", "From bows to atlatls, the tools survivalists brought to hunt."],
    "pot"                => ["Pots & Cookware", "The cooking pots and cookware survivalists brought to Naked and Afraid, and similar pots you can buy.", "A pot means boiled water and cooked food. These are the pots and cookware we have tied to the show."],
    "cordage"            => ["Cordage & Rope", "Paracord and cordage used on Naked and Afraid, and where to buy it.", "Cordage ties shelters, traps and tools together. Here is what survivalists carried."],
    "comfort item"       => ["Comfort Items", "The comfort items survivalists brought to Naked and Afraid, and similar products you can buy.", "A small comfort item can make 21 days survivable. These are the ones we could tie to the show."]
  }.freeze

  # One guide per gear category with at least three products.
  def self.guides
    products.group_by { |p| p[:category].to_s }.filter_map do |category, list|
      next if category.blank? || NON_GEAR.include?(category) || list.size < 3
      noun, desc, intro = GUIDE_COPY[category] || [category == "other" ? "More Gear" : category.titleize.pluralize, nil, nil]
      Guide.new(slug: category.parameterize, category: category,
                title: "#{noun} Used on Naked and Afraid", heading: noun,
                description: desc || "#{noun} Used on Naked and Afraid: the products we could tie to the show, with sources.",
                intro: intro || "Products tied to Naked and Afraid in the #{noun.downcase} category, with where each one was spotted.")
    end.sort_by(&:title)
  end

  def self.guide(slug) = guides.find { |g| g.slug == slug.to_s }

  # The guide a given product belongs to, if its category has one.
  def self.guide_for(product) = guides.find { |g| g.category == product[:category].to_s }

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

  # The buy buttons to show for a product: just its Amazon listing when it has one,
  # otherwise every other store it is sold at.
  def self.buy_links(product)
    links = Array(product[:buy])
    amazon = links.select { |l| amazon?(l) }
    amazon.any? ? amazon.first(1) : links
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
