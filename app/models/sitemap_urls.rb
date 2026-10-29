require "builder"

# The one list of URLs we offer to search engines, built from the database at request time
# (SitemapsController serves it at /sitemap.xml). This replaces the sitemap_generator gem,
# whose output lived in public/ and went stale the moment it was committed.
#
# Only public, indexable pages belong here. Never add /go/ redirects, /admin, the forum,
# auth pages or filtered/noindex views.
class SitemapUrls
  # Absolute URLs always use this host, never the host the request arrived on.
  HOST = "https://www.nakedandafraidfan.com".freeze

  # Bump to invalidate every cached sitemap after changing the URL set below.
  VERSION = 1

  Entry = Struct.new(:path, :lastmod, :changefreq, :priority, keyword_init: true) do
    def loc = "#{HOST}#{path == '/' ? '/' : path}"
  end

  # Tables whose rows feed the sitemap; the cache key follows their counts and newest update.
  SOURCES = [Survivor, Episode, Item, Season, Series, Location, FoodSource, EpisodeShelter].freeze

  class << self
    def entries = new.entries

    # Changes whenever a row is added, removed or edited in a source table, or the shop
    # guides change, so the cached XML is rebuilt on the next request.
    def cache_key
      stamps = SOURCES.map do |model|
        "#{model.table_name}:#{model.count}:#{model.maximum(:updated_at)&.utc&.to_f}"
      end
      guides = Digest::SHA256.hexdigest(ShopCatalog.guides.map(&:slug).join(","))[0, 16]
      "sitemap/v#{VERSION}/#{Digest::SHA256.hexdigest((stamps << guides).join('|'))}"
    end

    def to_xml(entries = self.entries)
      xml = Builder::XmlMarkup.new(indent: 0)
      xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
      xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
        entries.each do |e|
          xml.url do
            xml.loc e.loc
            xml.lastmod e.lastmod.utc.iso8601 if e.lastmod
            xml.changefreq e.changefreq
            xml.priority format("%.1f", e.priority)
          end
        end
      end
      xml.target!
    end
  end

  def entries
    @entries = []
    static_pages
    shop
    facets
    records
    @entries.uniq(&:path)
  end

  private

  include Rails.application.routes.url_helpers

  def add(path, changefreq:, priority:, lastmod: nil)
    @entries << Entry.new(path: path, lastmod: lastmod, changefreq: changefreq, priority: priority)
  end

  def static_pages
    add root_path,      changefreq: "daily",   priority: 1.0
    add home_path,      changefreq: "daily",   priority: 0.9
    add about_path,     changefreq: "monthly", priority: 0.5
    add podcasts_path,  changefreq: "weekly",  priority: 0.6
    add survivors_path, changefreq: "daily",   priority: 0.8
    add episodes_path,  changefreq: "daily",   priority: 0.8
    add items_path,     changefreq: "weekly",  priority: 0.7
  end

  def shop
    add shop_path,        changefreq: "weekly", priority: 0.5
    add shop_guides_path, changefreq: "weekly", priority: 0.5
    ShopCatalog.guides.each { |g| add shop_guide_path(g.slug), changefreq: "weekly", priority: 0.5 }
    add seasons_path,      changefreq: "weekly", priority: 0.7
    add series_index_path, changefreq: "weekly", priority: 0.7
  end

  # Filter / facet pages.
  def facets
    Location.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country).each do |country|
      add by_country_episodes_path(country: country), changefreq: "weekly", priority: 0.6
    end

    Item.where.not(item_type: [nil, ""]).distinct.order(:item_type).pluck(:item_type).each do |type|
      add type_items_path(item_type: type), changefreq: "weekly", priority: 0.6
    end

    add food_sources_path, changefreq: "weekly", priority: 0.6
    FoodSource.distinct.order(:name).pluck(:name).compact.reject { |n| n.strip.empty? }.each do |name|
      add food_source_path(name: name), changefreq: "monthly", priority: 0.5
    end

    add shelters_path, changefreq: "weekly", priority: 0.6
    EpisodeShelter.distinct.order(:shelter_type).pluck(:shelter_type).compact.reject { |t| t.strip.empty? }.each do |type|
      add shelter_path(shelter_type: type), changefreq: "monthly", priority: 0.5
    end

    add locations_path, changefreq: "weekly", priority: 0.6
  end

  def records
    Survivor.find_each { |s| add survivor_path(s), lastmod: s.updated_at, changefreq: "weekly",  priority: 0.7 }
    Episode.find_each  { |e| add episode_path(e),  lastmod: e.updated_at, changefreq: "weekly",  priority: 0.7 }
    Item.find_each     { |i| add item_path(i),     lastmod: i.updated_at, changefreq: "monthly", priority: 0.5 }
    Season.find_each   { |s| add season_path(s),   lastmod: s.updated_at, changefreq: "monthly", priority: 0.6 }
    Series.find_each   { |s| add series_path(s),   lastmod: s.updated_at, changefreq: "monthly", priority: 0.6 }
  end
end
