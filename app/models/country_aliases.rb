# Misspellings and alternate names for filming countries, read from config/country_aliases.yml
# (canonical country => [aliases]). Pure lookups; the redirect itself lives in NameSlugs
# (a country URL that is only an alias resolves to the canonical country's slug) and the
# displayed lines in the by_country and locations views.
module CountryAliases
  PATH = Rails.root.join("config/country_aliases.yml")

  class << self
    # { "colombia" => ["Columbia"], ... } keyed by the stripped, lower-cased canonical name.
    def table
      @table ||= load_table
    end

    def reset!
      @table = @by_alias_slug = @canonical_names = @raw = nil
    end

    # The aliases of a country (any case), [] when it has none.
    def for(country)
      table.fetch(country.to_s.strip.downcase, [])
    end

    # The canonical country name an alias stands for (an alias, its slug or any case of it),
    # or nil. A name shared by several countries ("Trinidad and Tobago") answers with the
    # first one listed in the file.
    def canonical_for(text)
      slug = text.to_s.parameterize
      return nil if slug.blank?
      canonicals_for(slug).first
    end

    # Every canonical country that lists this alias; lets a caller prefer one that exists.
    def canonicals_for(text)
      slug = text.to_s.parameterize
      return [] if slug.blank?
      by_alias_slug.fetch(slug, [])
    end

    # Does any alias of `country` contain the search text (case-insensitive substring)?
    def match?(country, needle)
      needle = needle.to_s.strip.downcase
      return false if needle.blank?
      self.for(country).any? { |a| a.downcase.include?(needle) }
    end

    # The alias(es) of `country` that contain the search text, for "matched as ..." hints.
    def matching(country, needle)
      needle = needle.to_s.strip.downcase
      return [] if needle.blank?
      self.for(country).select { |a| a.downcase.include?(needle) }
    end

    private

    def by_alias_slug
      @by_alias_slug ||= table.each_with_object({}) do |(key, aliases), h|
        aliases.each { |a| (h[a.parameterize] ||= []) << canonical_names[key] }
      end
    end

    def canonical_names
      @canonical_names ||= raw.keys.to_h { |name| [name.to_s.strip.downcase, name.to_s.strip] }
    end

    def raw
      @raw ||= begin
        data = YAML.safe_load_file(PATH) || {}
        data.transform_values { |list| Array(list).map { |a| a.to_s.strip }.reject(&:blank?).uniq }
      rescue Errno::ENOENT
        {}
      end
    end

    def load_table
      by_key = {}
      raw.each { |name, list| by_key[name.to_s.strip.downcase] = list }
      by_key.freeze
    end
  end
end
