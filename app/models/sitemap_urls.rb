require "builder"

# The one list of URLs we offer to search engines, built from the database at request time
# (SitemapsController serves it at /sitemap.xml). This replaces the sitemap_generator gem,
# whose output lived in public/ and went stale the moment it was committed.
#
# Only public, indexable pages belong here. Never add /go/ redirects, /admin, auth pages,
# paginated list pages beyond the clean first-page URL, or filtered/noindex views. The
# forum (topic list and topics) is listed only while FORUM_ENABLED is on, as it is
# otherwise a 404; the Community Guidelines page is public either way. /home is not listed:
# it 301s to /.
#
# Every entry carries a <lastmod>, taken from the data behind the page (see #latest and the
# STATIC_LASTMOD table for pages with no data behind them).
class SitemapUrls
  # Absolute URLs always use this host, never the host the request arrived on.
  HOST = "https://www.nakedandafraidfan.com".freeze

  # Bump to invalidate every cached sitemap after changing the URL set below.
  # (3: episode, item, country, food source, shelter and item-type pages moved to slug URLs.
  #  4: region hubs, /seasons/latest and the localized episode guides were added.)
  VERSION = 5

  # <lastmod> for pages whose content is a template, not data. There is no way to read a
  # template's last git commit at runtime on Heroku, so each is the date of its last
  # substantive revision, kept here by hand: change the date when you change the page.
  # The cache key includes a digest of this table, so a deploy that edits a date
  # refreshes the cached sitemap.
  STATIC_LASTMOD = {
    "/about"            => Date.new(2026, 11, 2),
    "/podcasts"         => Date.new(2026, 10, 29),
    "/contact"          => Date.new(2026, 11, 2),
    "/privacy_policy"   => Date.new(2026, 11, 20), # "Last updated" shown on the page
    "/terms_of_service" => Date.new(2026, 11, 1),  # "Last updated" shown on the page
    "/forum/guidelines" => StaticPagesController::GUIDELINES_UPDATED_ON
  }.freeze

  # Used when a data-backed page has no rows to take a date from (an empty table).
  FALLBACK_LASTMOD = Date.new(2026, 11, 1)

  Entry = Struct.new(:path, :lastmod, :changefreq, :priority, keyword_init: true) do
    def loc = "#{HOST}#{path == '/' ? '/' : path}"
  end

  # Tables whose rows feed the sitemap; the cache key follows their counts and newest update.
  SOURCES = [Survivor, Episode, Item, Season, Series, Location, FoodSource, EpisodeShelter,
             Appearance, AppearanceItem].freeze

  # The forum is only linked while it is open (see Forum::BaseController#ensure_forum_available).
  def self.forum_open? = ENV["FORUM_ENABLED"] == "true"

  class << self
    def entries = new.entries

    # Changes whenever a row is added, removed or edited in a source table (forum topics
    # too, while the forum is open), the shop catalog or its guides change, or the code's
    # URL set / lastmod constants change (VERSION and the STATIC_LASTMOD table), so the
    # cached XML is rebuilt on the next request.
    def cache_key
      stamps = SOURCES.map do |model|
        "#{model.table_name}:#{model.count}:#{model.maximum(:updated_at)&.utc&.to_f}"
      end
      stamps << forum_stamp
      stamps << "shop:#{ShopCatalog.guides.map(&:slug).join(',')}:#{shop_updated_at.to_i}"
      stamps << "static:#{STATIC_LASTMOD.map { |path, date| "#{path}=#{date}" }.join(',')}:#{FALLBACK_LASTMOD}"
      # Region membership lives in a config file: editing it (a deploy) refreshes the cache.
      stamps << "regions:#{file_digest(Regions::PATH)}"
      "sitemap/v#{VERSION}/#{Digest::SHA256.hexdigest(stamps.join('|'))}"
    end

    def file_digest(path)
      Digest::SHA256.file(path).hexdigest
    rescue SystemCallError
      "missing"
    end

    # mtime of config/shop_products.yml: the shop pages' lastmod. (On Heroku that is the
    # time of the deploy that shipped the file.)
    def shop_updated_at
      File.mtime(ShopCatalog::PATH).utc
    rescue SystemCallError
      nil
    end

    def forum_stamp
      return "forum:closed" unless forum_open?
      topics = Forum::Topic.active
      "forum:#{topics.count}:#{topics.maximum(:updated_at)&.utc&.to_f}:#{topics.maximum(:last_post_at)&.utc&.to_f}"
    end

    def to_xml(entries = self.entries)
      xml = Builder::XmlMarkup.new(indent: 0)
      xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
      xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
        entries.each do |e|
          xml.url do
            xml.loc e.loc
            xml.lastmod format_lastmod(e.lastmod) if e.lastmod
            xml.changefreq e.changefreq
            xml.priority format("%.1f", e.priority)
          end
        end
      end
      xml.target!
    end

    # W3C datetime: a plain date (YYYY-MM-DD) for hand-kept dates, a UTC timestamp for data.
    def format_lastmod(value)
      value.is_a?(Date) && !value.is_a?(DateTime) ? value.iso8601 : value.utc.iso8601
    end
  end

  def entries
    @entries = []
    static_pages
    shop
    facets
    records
    forum
    @entries.uniq(&:path)
  end

  private

  include Rails.application.routes.url_helpers

  def add(path, changefreq:, priority:, lastmod: nil)
    @entries << Entry.new(path: path, lastmod: lastmod || STATIC_LASTMOD[path] || FALLBACK_LASTMOD,
                          changefreq: changefreq, priority: priority)
  end

  # Newest of the given dates/times (nils ignored); the fallback when there are none.
  # Dates (from STATIC_LASTMOD) and times (from updated_at columns) can be mixed.
  def latest(*values)
    times = values.flatten.compact.map { |v| v.is_a?(Date) && !v.is_a?(DateTime) ? v.in_time_zone("UTC") : v.utc }
    times.max || FALLBACK_LASTMOD
  end

  # MAX(updated_at) of a model, looked up once per build.
  def stamp(model)
    @stamps ||= {}
    @stamps.fetch(model) { @stamps[model] = model.maximum(:updated_at) }
  end

  def static_pages
    add root_path,      changefreq: "daily",   priority: 1.0, lastmod: latest(stamp(Episode), stamp(Survivor), stamp(Item))
    add about_path,     changefreq: "monthly", priority: 0.5
    add podcasts_path,  changefreq: "weekly",  priority: 0.6
    add contact_path,   changefreq: "monthly", priority: 0.3
    add privacy_policy_path,   changefreq: "yearly", priority: 0.2
    add terms_of_service_path, changefreq: "yearly", priority: 0.2
    # The one forum URL that is public and crawlable whether or not the forum is open.
    add forum_guidelines_path, changefreq: "monthly", priority: 0.3
    add survivors_path, changefreq: "daily",   priority: 0.8, lastmod: latest(stamp(Survivor), stamp(Appearance))
    add episodes_path,  changefreq: "daily",   priority: 0.8, lastmod: latest(stamp(Episode), stamp(Season))
    add items_path,     changefreq: "weekly",  priority: 0.7, lastmod: latest(stamp(Item), stamp(AppearanceItem))
  end

  def shop
    shop_lastmod = self.class.shop_updated_at || FALLBACK_LASTMOD
    add shop_path,        changefreq: "weekly", priority: 0.5, lastmod: shop_lastmod
    add shop_guides_path, changefreq: "weekly", priority: 0.5, lastmod: shop_lastmod
    ShopCatalog.guides.each { |g| add shop_guide_path(g.slug), changefreq: "weekly", priority: 0.5, lastmod: shop_lastmod }
    add seasons_path,      changefreq: "weekly", priority: 0.7, lastmod: latest(stamp(Season), stamp(Series))
    add latest_seasons_path, changefreq: "daily", priority: 0.7, lastmod: latest(stamp(Episode), stamp(Season))
    add series_index_path, changefreq: "weekly", priority: 0.7, lastmod: latest(stamp(Series), stamp(Season))
    # Localized guide pages (hreflang alternates of each other; see EpisodeGuides).
    EpisodeGuides::PATHS.each_value do |path|
      add path, changefreq: "weekly", priority: 0.5, lastmod: latest(stamp(Episode), stamp(Season), stamp(Series))
    end
  end

  # Filter / facet pages. Lists carry the newest change in the data behind them; each
  # facet page the newest change among its own rows.
  def facets
    # Names and their slug URLs come from NameSlugs, so a page is listed under exactly the
    # URL it serves (the old spaced / numeric spellings only redirect and are never listed).
    # Lastmod lookups are keyed the way NameSlugs keys a name (stripped, lower-cased for
    # countries and food sources).
    country_episodes = Episode.joins(:location).group("locations.country").maximum("episodes.updated_at")
    country_places   = Location.group(:country).maximum(:updated_at)
    country_stamp = ->(hash, name) { hash.select { |k, _| k.to_s.strip.downcase == name.to_s.strip.downcase }.values }
    NameSlugs.all(:country).each do |country, slug|
      add by_country_episodes_path(country: slug), changefreq: "weekly", priority: 0.6,
          lastmod: latest(country_stamp.(country_episodes, country), country_stamp.(country_places, country))
    end

    # Region hubs (config/regions.yml): only regions that have episodes, each dated by the
    # newest change among its countries' episodes and locations.
    Regions.summaries.each do |summary|
      stamps = summary.countries.flat_map { |c| [country_stamp.(country_episodes, c[:name]), country_stamp.(country_places, c[:name])] }
      add by_region_episodes_path(region: summary.slug), changefreq: "weekly", priority: 0.6, lastmod: latest(stamps)
    end

    type_stamps = Item.group(:item_type).maximum(:updated_at)
    NameSlugs.all(:item_type).each do |type, slug|
      add type_items_path(item_type: slug), changefreq: "weekly", priority: 0.6, lastmod: latest(type_stamps[type])
    end

    add food_sources_path, changefreq: "weekly", priority: 0.6, lastmod: latest(stamp(FoodSource))
    food_stamps = FoodSource.group(:name).maximum(:updated_at)
    NameSlugs.all(:food_source).each do |name, slug|
      add food_source_path(name: slug), changefreq: "monthly", priority: 0.5, lastmod: latest(food_stamps[name])
    end

    add shelters_path, changefreq: "weekly", priority: 0.6, lastmod: latest(stamp(EpisodeShelter))
    shelter_stamps = EpisodeShelter.group(:shelter_type).maximum(:updated_at)
    NameSlugs.all(:shelter).each do |type, slug|
      add shelter_path(shelter_type: slug), changefreq: "monthly", priority: 0.5, lastmod: latest(shelter_stamps[type])
    end

    add locations_path, changefreq: "weekly", priority: 0.6, lastmod: latest(stamp(Location), stamp(Episode))
  end

  def records
    Survivor.find_each { |s| add survivor_path(s), lastmod: s.updated_at, changefreq: "weekly",  priority: 0.7 }
    Episode.find_each  { |e| add episode_path(e),  lastmod: e.updated_at, changefreq: "weekly",  priority: 0.7 }
    Item.find_each     { |i| add item_path(i),     lastmod: i.updated_at, changefreq: "monthly", priority: 0.5 }
    Season.find_each   { |s| add season_path(s),   lastmod: s.updated_at, changefreq: "monthly", priority: 0.6 }
    Series.find_each   { |s| add series_path(s),   lastmod: s.updated_at, changefreq: "monthly", priority: 0.6 }
  end

  # The topic list and every live topic, mirroring Forum::TopicsController: nothing here
  # while FORUM_ENABLED is off (the forum is a 404), soft-deleted topics never. Only page
  # one of the list is listed, not ?page=N.
  def forum
    return unless self.class.forum_open?
    topics = Forum::Topic.active
    add forum_path, changefreq: "daily", priority: 0.5,
        lastmod: latest(topics.maximum(:last_post_at) || topics.maximum(:updated_at))
    topics.order(:id).pluck(:slug, :last_post_at, :updated_at).each do |slug, last_post_at, updated_at|
      next if slug.blank?
      add forum_topic_path(slug), changefreq: "weekly", priority: 0.4, lastmod: latest(last_post_at || updated_at)
    end
  end
end
