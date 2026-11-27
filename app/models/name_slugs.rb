# Hyphenated URL slugs for the things that have no table of their own: filming countries
# (/episodes/by_country/south-africa), food sources (/food_sources/angel-fish), shelter
# types (/shelters/lean-to) and item types (/items/types/fire-starting-tool). Each is just
# a string column on another table, so there is no slug column; the slug is the name run
# through #parameterize and resolved back by comparing against every distinct name.
#
# Two different names can parameterize to the same slug ("Guinea Bissau" / "Guinea-Bissau",
# "Cote d'Ivoire" / "Côte d'Ivoire"). The generator and the resolver both work from the
# same mapping, built from the sorted distinct names, so they always agree: the first name
# in sorted order keeps the plain slug and the others get -2, -3... in sorted order. A name
# that parameterizes to nothing (all punctuation or a non-Latin script) falls back to the
# kind's word ("country", "country-2", ...).
#
# The mapping is read from the database once per request (Current), and rebuilt once if a
# name is missing from it (a record created earlier in the same request or test).
module NameSlugs
  Kind = Struct.new(:name, :fallback, :key, :source, keyword_init: true)

  # `key` collapses spellings that the pages already treated as one place/thing (the
  # country and food-source pages always compared case-insensitively). `source` returns
  # { raw name => row count }, used to pick the display spelling of a key.
  KINDS = {
    country: Kind.new(
      name: :country, fallback: "country",
      key: ->(raw) { raw.to_s.strip.downcase },
      source: -> { Location.where.not(country: [nil, ""]).group(:country).count }
    ),
    food_source: Kind.new(
      name: :food_source, fallback: "food",
      key: ->(raw) { raw.to_s.strip.downcase },
      source: -> { FoodSource.where.not(name: [nil, ""]).group(:name).count }
    ),
    shelter: Kind.new(
      name: :shelter, fallback: "shelter",
      key: ->(raw) { raw.to_s.strip },
      source: -> { EpisodeShelter.where.not(shelter_type: [nil, ""]).group(:shelter_type).count }
    ),
    item_type: Kind.new(
      name: :item_type, fallback: "type",
      key: ->(raw) { raw.to_s.strip },
      source: -> { Item.where.not(item_type: [nil, ""]).group(:item_type).count }
    )
  }.freeze

  # What the three lookups return: +name+ is the display spelling the page should use
  # (and query with, via +key+); +slug+ the canonical URL segment.
  Match = Struct.new(:name, :key, :slug, keyword_init: true)

  Mapping = Struct.new(:slug_by_key, :key_by_slug, :display_by_key, keyword_init: true)

  class << self
    # The canonical slug for a name (or for a slug that is already canonical).
    # Never raises: a name nowhere in the data still gets its plain parameterized form.
    def slug(kind, name)
      kind = fetch_kind(kind)
      text = name.to_s
      return nil if text.blank?
      with_mapping(kind) do |mapping|
        key = kind.key.call(text)
        mapping.slug_by_key[key] || (mapping.key_by_slug.key?(text) ? text : nil)
      end || plain_slug(text, kind)
    end

    # The page's name for a requested URL segment, or nil if nothing matches. A Match
    # whose slug differs from the segment (#redirect?) is an old or hand-typed URL that
    # should 301 to the canonical slug.
    def resolve(kind, segment)
      kind = fetch_kind(kind)
      text = segment.to_s
      return nil if text.blank?
      with_mapping(kind) do |mapping|
        match_in(kind, mapping, text)
      end || resolve_alias(kind, text)
    end

    # Every [name, slug] pair, in sorted order, for pages that list them all.
    def all(kind)
      kind = fetch_kind(kind)
      mapping = mapping_for(kind)
      mapping.slug_by_key.map { |key, slug| [mapping.display_by_key[key], slug] }
    end

    def reset!
      Current.name_slug_mappings = nil
    end

    # Pure function behind the mapping, public so the collision rules can be tested
    # without a database: keys in, { key => unique slug } out.
    def assign_slugs(keys, fallback:)
      bases = keys.sort.to_h { |key| [key, key.to_s.parameterize.presence || fallback] }
      taken = {}
      # First pass: the first key (sorted) of each base keeps the plain slug, so a name
      # whose natural slug looks like "foo-2" cannot be displaced by a suffixed duplicate.
      bases.each { |key, base| taken[base] ||= key }
      result = taken.invert
      bases.each do |key, base|
        next if result.key?(key)
        n = 2
        n += 1 while taken.key?("#{base}-#{n}")
        taken["#{base}-#{n}"] = key
        result[key] = "#{base}-#{n}"
      end
      result.slice(*bases.keys)
    end

    private

    def fetch_kind(kind)
      kind.is_a?(Kind) ? kind : KINDS.fetch(kind.to_sym)
    end

    def plain_slug(text, kind)
      text.parameterize.presence || kind.fallback
    end

    # A country URL that is only a common misspelling or alternate name ("columbia",
    # "phillipines", config/country_aliases.yml) resolves to the real country, so the
    # page 301s to its slug. Real names are tried first (see #resolve), and an alias for a
    # country that is not in the data is still a not-found.
    def resolve_alias(kind, text)
      return nil unless kind.name == :country
      CountryAliases.canonicals_for(text).each do |canonical|
        match = with_mapping(kind) { |mapping| match_in(kind, mapping, canonical) }
        return match if match
      end
      nil
    end

    def match_in(kind, mapping, text)
      # Already a canonical slug.
      if (key = mapping.key_by_slug[text])
        return build_match(mapping, key, text)
      end
      # An old URL: the name itself, in any case, with %20 (decoded to a space), "+" or
      # underscores for spaces.
      [text, text.tr("+", " "), text.tr("_", " ")].each do |candidate|
        key = kind.key.call(candidate)
        if (slug = mapping.slug_by_key[key])
          return build_match(mapping, key, slug)
        end
      end
      # A slug typed in the wrong case or with other punctuation ("South-Africa",
      # "cote-d'ivoire", "Cote d Ivoire").
      if (key = mapping.key_by_slug[text.parameterize])
        return build_match(mapping, key, mapping.slug_by_key[key])
      end
      nil
    end

    def build_match(mapping, key, slug)
      Match.new(name: mapping.display_by_key[key], key: key, slug: slug)
    end

    # Yields the memoized mapping; when the block returns nil (name not found) the mapping
    # is rebuilt from the database once and the block runs again.
    def with_mapping(kind)
      memoized = Current.name_slug_mappings&.key?(kind.name)
      result = yield mapping_for(kind)
      return result if result || !memoized
      yield mapping_for(kind, refresh: true)
    end

    def mapping_for(kind, refresh: false)
      Current.name_slug_mappings ||= {}
      Current.name_slug_mappings.delete(kind.name) if refresh
      Current.name_slug_mappings[kind.name] ||= build_mapping(kind)
    end

    def build_mapping(kind)
      counts = kind.source.call
      by_key = counts.group_by { |raw, _| kind.key.call(raw) }
      by_key.delete("")
      # The display spelling of a key is its most common raw spelling (ties: alphabetical).
      display = by_key.transform_values { |rows| rows.min_by { |raw, n| [-n, raw] }.first.to_s.strip }
      slugs = assign_slugs(by_key.keys, fallback: kind.fallback)
      Mapping.new(slug_by_key: slugs, key_by_slug: slugs.invert, display_by_key: display)
    end
  end
end
