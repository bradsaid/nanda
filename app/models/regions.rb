# Region / continent hubs (/episodes/by_region/africa): the mapping of filming countries to
# regions lives in config/regions.yml, everything shown about a region is computed from the
# episodes whose location is in it. A region with no episodes does not exist as far as the
# site is concerned (no page, no links, no sitemap entry).
module Regions
  PATH = Rails.root.join("config/regions.yml")

  Region = Struct.new(:name, :slug, :aliases, :countries, keyword_init: true) do
    # Lower-cased, stripped country names, the way episodes are matched
    # (TRIM(LOWER(locations.country))).
    def country_keys = @country_keys ||= countries.map { |c| c.to_s.strip.downcase }
    def to_param = slug
  end

  # A region together with the countries in it that have episodes (each { name:, slug:,
  # episodes: }, most episodes first) and the episode total.
  Summary = Struct.new(:region, :countries, :episode_count, keyword_init: true) do
    delegate :name, :slug, to: :region
  end

  class << self
    def all
      @all ||= load_regions
    end

    def reset!
      @all = nil
    end

    # The region for a URL segment: its slug, or any other spelling of the slug or of one of
    # the region's aliases (case, spaces, "&"). nil when nothing matches. The caller
    # redirects when region.slug differs from the segment.
    def find(segment)
      text = segment.to_s.strip
      return nil if text.blank?
      slug = text.parameterize
      all.find { |r| r.slug == text } ||
        all.find { |r| r.slug == slug } ||
        all.find { |r| r.aliases.any? { |a| a.parameterize == slug } }
    end

    # The region a filming country belongs to, or nil.
    def for_country(country)
      key = country.to_s.strip.downcase
      return nil if key.blank?
      all.find { |r| r.country_keys.include?(key) }
    end

    # Regions that have episodes, in the order of the config file.
    def summaries
      counts = country_episode_counts
      all.filter_map { |region| summary_for(region, counts) }
    end

    def summary(region)
      summary_for(region, country_episode_counts)
    end

    # { stripped lower-cased country => episode count } over every episode with a location.
    def country_episode_counts
      Episode.joins(:location)
             .where.not(locations: { country: [nil, ""] })
             .group(Arel.sql("TRIM(LOWER(locations.country))")).count
    end

    # Episodes whose location is in the region.
    def episodes_in(region)
      Episode.joins(:location).where("TRIM(LOWER(locations.country)) IN (?)", region.country_keys)
    end

    private

    def summary_for(region, counts)
      present = region.country_keys.filter_map do |key|
        n = counts[key].to_i
        next unless n.positive?
        name = NameSlugs.resolve(:country, key)
        { name: name&.name || key.titleize, slug: name&.slug || key.parameterize, episodes: n }
      end
      return nil if present.empty?
      Summary.new(region: region, episode_count: present.sum { |c| c[:episodes] },
                  countries: present.sort_by { |c| [-c[:episodes], c[:name]] })
    end

    def load_regions
      data = YAML.safe_load_file(PATH) || []
      data.map do |row|
        name = row.fetch("name").to_s.strip
        Region.new(name: name, slug: name.parameterize, aliases: Array(row["aliases"]).map(&:to_s),
                   countries: Array(row["countries"]).map { |c| c.to_s.strip })
      end.freeze
    rescue Errno::ENOENT
      [].freeze
    end
  end
end
