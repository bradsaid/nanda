# Data-driven "quick facts" for the food source and shelter pages. Every number and name
# comes from the rows passed in (no invented facts); a fact the data cannot support is left
# out rather than shown as zero. The same sentences feed the visible summary and the meta
# description, so they cannot drift apart.
module FactPagesHelper
  # Rows are FoodSource / EpisodeShelter records loaded with episode: [:location, { season: :series }].
  Facts = Struct.new(:kind, :name, :category, :episode_count, :season_count, :countries, :first_year, :last_year,
                     :methods, :materials, :quantity_known, :quantity_total, :survivor_ids, :entries,
                     :examples, keyword_init: true)

  EXAMPLE_LIMIT = 3

  def food_source_facts(food_sources, name)
    rows = food_sources.to_a
    facts = base_facts(:food, name, rows)
    facts.category   = rows.first&.category
    facts.methods    = rows.filter_map { |r| r.method&.humanize&.downcase }.tally.sort_by { |m, n| [ -n, m ] }
    quantities       = rows.filter_map(&:quantity)
    facts.quantity_known = quantities.size
    facts.quantity_total = quantities.sum
    facts.survivor_ids   = rows.flat_map { |r| Array(r.survivor_ids) }.map(&:to_i).uniq
    facts
  end

  def shelter_facts(shelters, type)
    rows = shelters.to_a
    facts = base_facts(:shelter, type, rows)
    facts.materials    = rows.filter_map { |r| r.materials.to_s.squish.downcase.presence }.tally.sort_by { |m, n| [ -n, m ] }
    facts.survivor_ids = rows.flat_map { |r| Array(r.builder_ids) }.map(&:to_i).uniq
    facts
  end

  # Plain-text sentences for the page (and the meta description). Empty when there are no rows.
  def fact_sentences(facts)
    return [] if facts.entries.zero?
    kind = facts.kind
    seasons = pluralize(facts.season_count, "season")
    eps     = pluralize(facts.episode_count, "episode")
    label   = kind == :food ? facts.name.to_s.titleize : "#{facts.name} shelter"
    verb    = kind == :food ? "recorded as #{facts.category == 'plant' ? 'a plant' : 'an animal'} food source" : "built"
    first   = "#{label} was #{verb} in #{eps} across #{seasons} of Naked and Afraid"
    first  += (facts.first_year == facts.last_year ? " (#{facts.first_year})" : " (#{facts.first_year}–#{facts.last_year})") if facts.first_year
    sentences = [ "#{first}." ]
    if facts.countries.any?
      shown = facts.countries.first(4)
      more  = facts.countries.size - shown.size
      list  = more.positive? ? "#{shown.join(', ')} and #{more} more" : shown.to_sentence
      sentences << "It happened in #{list}."
    end
    if kind == :food
      if facts.methods.any?
        sentences << "Recorded methods: #{facts.methods.map { |m, n| "#{m} (#{n})" }.to_sentence}."
      end
      if facts.quantity_known.positive?
        sentences << "A quantity is recorded for #{facts.quantity_known} of #{pluralize(facts.entries, 'entry', 'entries')}, #{facts.quantity_total} in total."
      end
      if facts.survivor_ids.any?
        sentences << "#{pluralize(facts.survivor_ids.size, 'survivalist')} #{facts.survivor_ids.size == 1 ? 'is' : 'are'} credited with it; the rest of the entries are logged for the team."
      end
    else
      if facts.materials.any?
        sentences << "Materials recorded: #{facts.materials.first(5).map { |m, n| n > 1 ? "#{m} (#{n})" : m }.to_sentence}."
      end
      if facts.survivor_ids.any?
        sentences << "#{pluralize(facts.survivor_ids.size, 'survivalist')} #{facts.survivor_ids.size == 1 ? 'is' : 'are'} named as builders."
      end
    end
    sentences
  end

  # The meta description: the first two sentences, cut to the description limit.
  def fact_meta_description(facts, fallback)
    sentences = fact_sentences(facts)
    return fallback if sentences.empty?
    truncate_at_word(sentences.first(2).join(" "), SeoHelper::DESCRIPTION_LIMIT)
  end

  private

  def base_facts(kind, name, rows)
    episodes = rows.map(&:episode).compact.uniq
    years    = episodes.filter_map { |e| e.air_date&.year }
    Facts.new(
      kind: kind, name: name, entries: rows.size,
      episode_count: episodes.size,
      season_count: episodes.map(&:season_id).uniq.size,
      countries: episodes.filter_map { |e| e.location&.country.to_s.strip.presence }.tally.sort_by { |c, n| [ -n, c ] }.map(&:first),
      first_year: years.min, last_year: years.max,
      # most recent first; episodes without an air date last
      examples: episodes.sort_by { |e| [ e.air_date ? 0 : 1, -(e.air_date&.jd || 0), e.id ] }.first(EXAMPLE_LIMIT)
    )
  end
end
