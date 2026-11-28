# Titles, descriptions, FAQ and structured data for the region hubs (RegionsController).
# Everything is computed from the data passed in (a Regions::Summary and counts); no region
# fact is written by hand.
module RegionsHelper
  # "Naked and Afraid in Africa: Every Filming Location & Episode" (site name appended by
  # site_title when it fits). Long region names fall back to a shorter wording.
  def region_title(region)
    full  = "Naked and Afraid in #{region.name}: Every Filming Location & Episode"
    short = "Naked and Afraid in #{region.name}: Locations & Episodes"
    site_title(full, short, "Naked and Afraid in #{region.name}", "Filming in #{region.name}", region.name)
  end

  # Unique, <= 160 characters, naming as many of the region's places as fit.
  def region_meta_description(summary)
    n      = summary.countries.size
    places = summary.countries.map { |c| c[:name] }
    build = lambda do |list|
      named =
        if list.empty? then ""
        elsif list.size == places.size then ": #{list.to_sentence}"
        else ": #{list.join(', ')} and more"
        end
      "#{pluralize(summary.episode_count, 'Naked and Afraid episode')} filmed in #{summary.name} across #{pluralize(n, 'place')}#{named}. Air dates, locations and survivalists."
    end
    places.size.downto(0) do |k|
      text = build.call(places.first(k))
      return text if text.length <= SeoHelper::DESCRIPTION_LIMIT
    end
    truncate_at_word(build.call([]), SeoHelper::DESCRIPTION_LIMIT)
  end

  # "Our database has 12 episodes of Naked and Afraid filmed in Africa, ..." paragraph under the heading.
  def region_intro(summary, season_count:, survivor_count:)
    parts = ["Our database has #{pluralize(summary.episode_count, 'episode')} of Naked and Afraid filmed in #{summary.name}",
             "from #{pluralize(season_count, 'season')}",
             "across #{pluralize(summary.countries.size, 'place')}"]
    text = "#{parts[0]}, #{parts[1]}, #{parts[2]}"
    text += ", with #{pluralize(survivor_count, 'survivalist')} on record" if survivor_count.to_i.positive?
    "#{text}."
  end

  # {q:, a:, a_html:} pairs, answered from the data only. The visible FAQ and the FAQPage
  # JSON-LD both come from here.
  def region_faq_qas(summary)
    name      = summary.name
    countries = summary.countries
    linked    = countries.map { |c| link_to(c[:name], by_country_episodes_path(country: c[:name])) }
    counts    = countries.map { |c| "#{c[:name]} (#{pluralize(c[:episodes], 'episode')})" }
    qas = []

    where_html = safe_join(["Our database has episodes filmed in ",
                            safe_join(linked.each_with_index.map { |l, i| safe_join([l, " (#{pluralize(countries[i][:episodes], 'episode')})"]) }, ", "),
                            "."])
    qas << { q: "Where in #{name} was Naked and Afraid filmed?",
             a: "Our database has episodes filmed in #{counts.to_sentence}.", a_html: where_html }

    qas << { q: "How many Naked and Afraid episodes were filmed in #{name}?",
             a: "#{pluralize(summary.episode_count, 'episode')} in our database were filmed in #{name}." }

    top_n = countries.map { |c| c[:episodes] }.max
    top   = countries.select { |c| c[:episodes] == top_n }.map { |c| c[:name] }
    qas << { q: "Which place in #{name} has the most Naked and Afraid episodes?",
             a: top.size == 1 ? "#{top.first} has the most, with #{pluralize(top_n, 'episode')}." :
                                "#{top.to_sentence} are tied for the most, with #{pluralize(top_n, 'episode')} each." }
    qas
  end

  # The summary of the region a filming country belongs to (with episodes), or nil: feeds the
  # "More in Africa" links on the country pages and the region strip on /locations.
  def region_summary_for_country(country)
    region = Regions.for_country(country)
    region && Regions.summary(region)
  end

  # CollectionPage + ItemList of the region's places + BreadcrumbList + FAQPage.
  def region_jsonld(summary, qas:)
    base = request.base_url
    items = summary.countries.each_with_index.map do |c, i|
      { "@type" => "ListItem", "position" => i + 1,
        "url" => "#{base}#{by_country_episodes_path(country: c[:name])}", "name" => c[:name],
        "item" => { "@type" => "Place", "name" => c[:name], "url" => "#{base}#{by_country_episodes_path(country: c[:name])}",
                    "description" => pluralize(c[:episodes], "episode") + " filmed" } }
    end
    [
      { "@context" => "https://schema.org", "@type" => "CollectionPage",
        "name" => "Naked and Afraid in #{summary.name}", "url" => canonical_request_url,
        "description" => region_meta_description(summary),
        "about" => { "@type" => "Place", "name" => summary.name } },
      { "@context" => "https://schema.org", "@type" => "ItemList",
        "name" => "Naked and Afraid filming locations in #{summary.name}",
        "numberOfItems" => items.size, "itemListElement" => items },
      breadcrumb_jsonld([
        { name: "Home", path: root_path },
        { name: "Locations", path: locations_path },
        { name: summary.name, path: by_region_episodes_path(region: summary.slug) }
      ]),
      { "@context" => "https://schema.org", "@type" => "FAQPage",
        "mainEntity" => qas.map { |qa|
          { "@type" => "Question", "name" => qa[:q],
            "acceptedAnswer" => { "@type" => "Answer", "text" => (qa[:a_html].presence || qa[:a]).to_s } } } }
    ]
  end
end
