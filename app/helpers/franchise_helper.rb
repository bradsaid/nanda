# Titles, descriptions and question-and-answer blocks for the season, series and episode
# pages, and the /seasons and /series franchise guides. Every sentence is built from the
# numbers and names passed in (EpisodeSetOverview, FranchiseStats); a fact that is
# missing is left out rather than shown as zero or blank. The Q&As are both rendered on
# the page and emitted as FAQPage JSON-LD (faq_page_jsonld), so the markup always matches
# what a visitor can read.
module FranchiseHelper
  # Long cast lists are not names in a sentence; past this the answer points at the page.
  FAQ_CAST_NAME_LIMIT = 40
  # Results/tap-out names are listed in an answer only when the list is short.
  FAQ_RESULT_NAME_LIMIT = 12

  # ---------- names ----------

  # "Naked and Afraid: Solo" -> "Naked and Afraid Solo" (a colon inside a title that already
  # has a colon reads badly). The stored name is left alone everywhere else.
  def display_series_name(series_or_name)
    name = series_or_name.respond_to?(:name) ? series_or_name.name : series_or_name
    name.to_s.sub(/\A(naked\s+and\s+afraid)\s*:\s*/i, '\1 ').squish.presence || "Naked and Afraid"
  end

  # "Naked and Afraid XL Season 10" / "Naked and Afraid Season 11": the series is always in
  # the name, so an XL season never reads like the regular season with the same number.
  def season_full_name(season)
    "#{display_series_name(season.series)} Season #{season.number}"
  end

  def long_date(date) = date&.strftime("%B %-d, %Y")
  def short_date(date) = date&.strftime("%b %-d, %Y")

  # The first candidate that fits a search-result title, else the last (shortest) one.
  def fit_title(*candidates, limit: SeoHelper::MAX_TITLE_LENGTH)
    candidates.flatten.compact.find { |c| c.length <= limit } || candidates.flatten.compact.last
  end

  # "A, B and 2 more": at most `max` names, then how many were left out.
  def short_list(items, max: 3, more: "more")
    items = Array(items)
    return items.to_sentence if items.size <= max
    "#{items.first(max).join(', ')} and #{items.size - max} #{more}"
  end

  # ---------- FAQ plumbing ----------

  # One Q&A: `html` is the answer as safe HTML (links allowed); the plain-text answer is
  # derived from it so the two can never drift apart.
  def faq_qa(question, html)
    html = html.is_a?(ActiveSupport::SafeBuffer) ? html : ERB::Util.html_escape(html)
    plain = CGI.unescapeHTML(strip_tags(html.to_s)).squish
    { q: question, a: plain, a_html: html }
  end

  # "a, b and c" over safe-HTML items (links), like Array#to_sentence but html-safe.
  def html_sentence(items)
    items = Array(items)
    case items.size
    when 0 then "".html_safe
    when 1 then items.first
    when 2 then safe_join(items, " and ")
    else safe_join([safe_join(items[0..-2], ", "), ", and ", items.last])
    end
  end

  # Linked names, or just "N survivalists" when the list is too long to read.
  def survivor_links_or_count(survivors, limit: 30)
    survivors = Array(survivors)
    return pluralize(survivors.size, "survivalist") if survivors.size > limit
    safe_join(survivors.map { |s| link_to(s.full_name, survivor_path(s)) }, ", ")
  end

  # FAQPage schema for [{q:, a:, a_html:}]; nil when empty. Link hrefs are made absolute
  # for the schema (the page itself keeps relative links).
  def faq_page_jsonld(qas)
    qas = Array(qas)
    return nil if qas.empty?
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => qas.map { |qa|
        text = (qa[:a_html].presence || qa[:a]).to_s.gsub('href="/', "href=\"#{request.base_url}/")
        { "@type" => "Question", "name" => qa[:q], "acceptedAnswer" => { "@type" => "Answer", "text" => text } }
      }
    }
  end

  # ---------- season pages ----------

  def season_page_title(season)
    name = season_full_name(season)
    site_title(fit_title("#{name}: Cast, Episodes & Locations", "#{name}: Cast & Episodes", name))
  end

  def season_page_description(season, overview)
    name = season_full_name(season)
    n    = overview.episode_count
    return "#{name}: episode guide, cast and where to watch." if n.zero?
    years = overview.years_label || (season.year.to_i > 1900 ? season.year.to_s : nil)
    first = "#{name}#{" (#{years})" if years}: #{pluralize(n, 'episode')}"
    first += " filmed in #{short_list(overview.countries, max: 3, more: 'more')}" if overview.countries.any?
    cast = overview.survivors.size
    first += " with #{pluralize(cast, 'survivalist')}" if cast.positive?
    truncate_at_word("#{first}. Full cast, air dates and where to watch.", SeoHelper::DESCRIPTION_LIMIT)
  end

  # Services (key => url) for a season from the existing streaming map.
  def season_watch_services(season)
    services_for(season.series&.name, season.number)
  end

  def season_faq_qas(season, overview, services: nil)
    name = season_full_name(season)
    n    = overview.episode_count
    return [] if n.zero?
    services ||= season_watch_services(season)
    qas = []
    premiere, finale = overview.premiere, overview.finale

    count_text = "#{name} has #{pluralize(n, 'episode')}"
    count_text += premiere == finale ? ", which aired on #{long_date(premiere)}" : ", airing from #{long_date(premiere)} to #{long_date(finale)}" if premiere
    qas << faq_qa("How many episodes are in #{name}?", "#{count_text}.")

    if premiere
      text = "#{name} premiered on #{long_date(premiere)}."
      text += " The last episode in our guide aired on #{long_date(finale)}." if finale != premiere
      qas << faq_qa("When did #{name} premiere?", text)
    end

    qas.concat(filming_qas(name, overview))
    qas << cast_qa(name, overview)
    qas << days_qa(name, overview)
    qas << watch_qa(name, services)
    qas << results_qa(name, overview)
    qas << psr_qa(name, overview)
    qas << brought_items_qa(name, overview)
    qas.compact
  end

  # ---------- series hub pages ----------

  def series_page_title(series)
    name = display_series_name(series)
    site_title(fit_title("#{name}: Episodes, Cast, Location & Air Dates",
                         "#{name}: Episodes, Cast, Location & Dates",
                         "#{name}: Episodes, Cast & Location",
                         "#{name}: Episodes & Cast",
                         name))
  end

  def series_page_description(series, overview, seasons_count)
    name = display_series_name(series)
    n    = overview.episode_count
    return "#{name}: seasons, episodes, cast and where to watch." if n.zero?
    text = "#{name}: #{pluralize(n, 'episode')}"
    text += " in #{pluralize(seasons_count, 'season')}" if seasons_count > 1
    text += ", premiering #{short_date(overview.premiere)}" if overview.premiere
    text += ". Filmed in #{short_list(overview.countries, max: 2, more: 'more')}" if overview.countries.any?
    truncate_at_word("#{text}. Episode list, cast, air dates and where to watch.", SeoHelper::DESCRIPTION_LIMIT)
  end

  # TVSeries + BreadcrumbList (+ FAQPage when there are Q&As) for a series hub.
  def series_show_jsonld(series, seasons:, episode_count:, first_air:, qas:)
    tv = { "@context" => "https://schema.org", "@type" => "TVSeries", "name" => series.name,
           "url" => canonical_request_url, "numberOfSeasons" => seasons.size, "numberOfEpisodes" => episode_count }
    tv["startDate"] = first_air.to_s if first_air
    tv["description"] = series_synopsis(series) if series_synopsis(series)
    crumbs = breadcrumb_jsonld([{ name: "Home", path: root_path }, { name: "Series", path: series_index_path },
                                { name: series.name, path: series_path(series) }])
    [tv, crumbs, faq_page_jsonld(qas)].compact
  end

  def series_faq_qas(series, seasons, overview)
    name = display_series_name(series)
    n    = overview.episode_count
    return [] if n.zero?
    qas = []
    premiere = overview.premiere
    first_ep = overview.episodes.select(&:air_date).min_by { |e| [e.air_date, e.id] }

    if premiere
      text = safe_join(
        ["#{name} premiered on #{long_date(premiere)}",
         (first_ep ? [" with ", link_to("“#{first_ep.title}”", episode_path(first_ep))] : nil),
         "."].flatten.compact)
      qas << faq_qa("When did #{name} premiere?", text)
    end

    count_text = "#{name} has #{pluralize(n, 'episode')}"
    count_text += " across #{pluralize(seasons.size, 'season')}" if seasons.size > 1
    count_text += overview.finale == premiere ? ", all aired on #{long_date(premiere)}" : ", aired from #{long_date(premiere)} to #{long_date(overview.finale)}" if premiere
    qas << faq_qa("How many episodes are in #{name}?", "#{count_text}.")

    qas.concat(filming_qas(name, overview))
    qas << cast_qa(name, overview, seasons: seasons)
    qas << days_qa(name, overview)

    if overview.team_count
      arrangement = overview.team_arrangement
      qas << faq_qa("How many teams are in #{name}?",
                    "Our episode data records #{overview.team_count} teams#{" (arrangement #{arrangement})" if arrangement}.")
    end

    qas << series_watch_qa(name, series, seasons)
    qas << results_qa(name, overview)
    qas.compact
  end

  # ---------- shared Q&A pieces ----------

  def filming_qas(name, overview)
    return [] if overview.countries.empty?
    links = overview.countries.map { |c| link_to(c, by_country_episodes_path(c)) }
    html = safe_join(["#{name} was filmed in ", html_sentence(links), "."])
    sites = overview.location_counts.map(&:first)
    if sites.size.between?(1, 3) && sites.any? { |s| s.include?(",") }
      html = safe_join([html, " Filming location#{'s' if sites.size > 1}: #{sites.join('; ')}."])
    end
    [faq_qa("Where was #{name} filmed?", html)]
  end

  def cast_qa(name, overview, seasons: nil)
    cast = overview.survivors
    return nil if cast.empty?
    q = "Who is in the cast of #{name}?"
    if cast.size <= FAQ_CAST_NAME_LIMIT
      links = cast.map { |s| link_to(s.full_name, survivor_path(s)) }
      faq_qa(q, safe_join(["The #{pluralize(cast.size, 'survivalist')} in #{name} #{cast.size == 1 ? 'is' : 'are'} ", html_sentence(links), "."]))
    elsif seasons && seasons.size > 1
      links = seasons.first(8).map { |s| link_to("Season #{s.number}", season_path(s)) }
      more  = seasons.size > 8 ? ", and #{seasons.size - 8} more seasons" : ""
      faq_qa(q, safe_join(["#{name} has had #{pluralize(cast.size, 'survivalist')} across #{pluralize(seasons.size, 'season')}. Open a season for its full cast: ",
                           html_sentence(links), more, "."]))
    else
      faq_qa(q, "#{name} has #{pluralize(cast.size, 'survivalist')}; the full cast is listed on this page.")
    end
  end

  def days_qa(name, overview)
    days = overview.scheduled_days
    return nil if days.empty?
    text = if days.size == 1
      "The challenge in #{name} is scheduled for #{pluralize(days.first, 'day')}."
    else
      "Scheduled challenge lengths in #{name} range from #{days.first} to #{pluralize(days.last, 'day')}."
    end
    faq_qa("How many days is the challenge in #{name}?", text)
  end

  def watch_qa(name, services)
    return nil if services.blank?
    labels = services.keys.map { |k| streaming_label(k) }
    faq_qa("Where can I watch #{name}?",
           "Our streaming guide lists #{name} on #{labels.to_sentence}. Availability can vary by country and over time.")
  end

  def series_watch_qa(name, series, seasons)
    per_season = seasons.map { |s| services_for(series.name, s.number) }
    keys = per_season.flat_map(&:keys).uniq
    return nil if keys.empty?
    labels = keys.map { |k| streaming_label(k) }
    text = if seasons.size == 1
      "Our streaming guide lists #{name} on #{labels.to_sentence}."
    else
      "Seasons of #{name} are listed on #{labels.to_sentence}; which service carries which season varies, so check each season's page."
    end
    faq_qa("Where can I watch #{name}?", "#{text} Availability can vary by country and over time.")
  end

  # Only when some appearance has a recorded result, and worded as "on record" because
  # results exist for only part of the cast.
  def results_qa(name, overview)
    r = overview.results
    return nil unless r
    parts = []
    named = lambda do |label, survivors|
      next if survivors.empty?
      if survivors.size <= FAQ_RESULT_NAME_LIMIT
        parts << safe_join(["#{label}: ", html_sentence(survivors.map { |s| link_to(s.full_name, survivor_path(s)) })])
      else
        parts << "#{label}: #{survivors.size} survivalists"
      end
    end
    named.call("completed the challenge", r.completed)
    named.call("tapped out", r.tapped_out)
    named.call("were eliminated", r.eliminated)
    return nil if parts.empty?
    lead = "Our database has a recorded result for #{r.recorded} of #{pluralize(r.survivor_total, 'survivalist')} in #{name}"
    faq_qa("Who tapped out in #{name}?", safe_join(["#{lead}. ", safe_join(parts, "; "), "."]))
  end

  def psr_qa(name, overview)
    top = overview.top_psr
    return nil unless top
    links = top[:survivors].map { |s| link_to(s.full_name, survivor_path(s)) }
    faq_qa("What was the highest PSR in #{name}?",
           safe_join(["The highest ending PSR on record for #{name} is #{EpisodeSetOverview.format_psr(top[:value])}, for ", html_sentence(links), "."]))
  end

  def brought_items_qa(name, overview)
    items = overview.brought_items
    return nil if items.empty?
    links = items.map { |item, count| safe_join([link_to(item.name, item_path(item)), " (#{count})"]) }
    faq_qa("What items were brought most in #{name}?",
           safe_join(["The items brought by the most survivalists in #{name} were ", html_sentence(links), "."]))
  end

  # ---------- /seasons and /series franchise guides ----------

  def stats_series_by_id(stats, id) = stats[:series].find { |r| r[:id] == id }

  def stats_flagship(stats) = stats_series_by_id(stats, stats[:flagship_id])

  def stats_spin_offs(stats) = stats[:series].reject { |r| r[:id] == stats[:flagship_id] }

  def stats_series_link(row) = link_to(display_series_name(row[:name]), series_path(row[:id]))

  def stats_marker_link(marker)
    return nil unless marker
    label = "#{display_series_name(marker[:series_name])} Season #{marker[:season_number]}"
    link_to(label, season_path(marker[:season_id]))
  end

  def seasons_index_title = site_title("All Naked and Afraid Seasons: Episodes, Cast & Where to Watch")

  def seasons_index_description(stats)
    return "Every Naked and Afraid season with episode counts, cast and where to watch." if stats[:total_seasons].zero?
    text = "All #{pluralize(stats[:total_seasons], 'Naked and Afraid season')}"
    text += " across #{pluralize(stats[:total_series], 'series', 'series')}" if stats[:total_series] > 1
    text += " (#{pluralize(stats[:total_episodes], 'episode')})" if stats[:total_episodes].positive?
    first = stats[:first_aired]
    text += ", from #{first[:date].year}" if first
    truncate_at_word("#{text}: cast, air dates, filming locations and where to watch.", SeoHelper::DESCRIPTION_LIMIT)
  end

  def series_index_title = site_title("Naked and Afraid Series in Order: Every Spin-off")

  def series_index_description(stats)
    return "Every Naked and Afraid series: seasons, episodes and where to watch." if stats[:total_series].zero?
    text = "Every Naked and Afraid series in order of first airing: #{pluralize(stats[:total_series], 'series', 'series')}, " \
           "#{pluralize(stats[:total_seasons], 'season')}, #{pluralize(stats[:total_episodes], 'episode')}"
    tail = "Premiere dates, filming countries and where to watch."
    truncate_at_word("#{text}. #{tail}", SeoHelper::DESCRIPTION_LIMIT)
  end

  # Season-oriented FAQ for /seasons.
  def seasons_index_faq_qas(stats)
    return [] if stats[:total_seasons].zero?
    qas = []
    flagship = stats_flagship(stats)
    spin_offs = stats_spin_offs(stats)

    seasons_text = if flagship && spin_offs.any?
      safe_join(["The original ", stats_series_link(flagship), " series has #{pluralize(flagship[:seasons], 'season')}. ",
                 "Counting the #{pluralize(spin_offs.size, 'spin-off')}, there are #{stats[:total_seasons]} seasons across #{pluralize(stats[:total_series], 'series', 'series')}."])
    elsif flagship
      safe_join(["There #{flagship[:seasons] == 1 ? 'is' : 'are'} #{pluralize(flagship[:seasons], 'season')} of ", stats_series_link(flagship), "."])
    else
      "There are #{pluralize(stats[:total_seasons], 'season')} across #{pluralize(stats[:total_series], 'series', 'series')}."
    end
    qas << faq_qa("How many seasons of Naked and Afraid are there?", seasons_text)

    if stats[:total_episodes].positive?
      eps_text = if flagship && flagship[:episodes].positive? && spin_offs.any?
        "Our guide lists #{pluralize(flagship[:episodes], 'episode')} of the original series and #{stats[:total_episodes]} episodes across every series."
      else
        "Our guide lists #{pluralize(stats[:total_episodes], 'episode')}."
      end
      qas << faq_qa("How many episodes of Naked and Afraid are there?", eps_text)
    end

    first = stats[:first_aired]
    if first
      qas << faq_qa("When did Naked and Afraid first air?",
                    safe_join(["The earliest episode in our guide, ", link_to("“#{first[:title]}”", episode_path(first[:episode_param])),
                               " (#{display_series_name(first[:series_name])} Season #{first[:season_number]}), aired on #{long_date(first[:date])}."]))
    end

    last = stats[:last_aired]
    if last
      qas << faq_qa("What is the most recent season of Naked and Afraid?",
                    safe_join(["The most recently aired episode in our guide is from ", stats_marker_link(last), ", on #{long_date(last[:date])}."]))
    end

    qas << faq_qa("In what order should I watch the seasons?",
                  "Within each series, watch the seasons in number order; the table below lists every series in the order it first aired. Regular and XL seasons share numbers, so check the series name.")

    services = SeasonsHelper.season_services.values.flat_map { |by_season| by_season.values.flat_map(&:keys) }.uniq
    if services.any?
      qas << faq_qa("Where can I watch Naked and Afraid?",
                    "Our streaming guide lists seasons on #{services.map { |k| streaming_label(k) }.to_sentence}. The table on this page shows the services for each season.")
    end
    qas
  end

  # Series-oriented FAQ for /series.
  def series_index_faq_qas(stats)
    return [] if stats[:total_series].zero?
    qas = []
    flagship = stats_flagship(stats)
    spin_offs = stats_spin_offs(stats)

    qas << faq_qa("How many Naked and Afraid series are there?",
                  "Our guide covers #{pluralize(stats[:total_series], 'series', 'series')}, with #{pluralize(stats[:total_seasons], 'season')} and #{pluralize(stats[:total_episodes], 'episode')} in total.")

    if flagship && spin_offs.any?
      qas << faq_qa("What are the Naked and Afraid spin-offs?",
                    safe_join(["Besides the original ", stats_series_link(flagship), ", our guide lists ",
                               html_sentence(spin_offs.map { |r| stats_series_link(r) }), "."]))
    end

    first = stats[:first_aired]
    if first
      qas << faq_qa("When did Naked and Afraid first air?",
                    "The earliest episode in our guide aired on #{long_date(first[:date])} (#{display_series_name(first[:series_name])} Season #{first[:season_number]}).")
    end

    dated = stats[:series].select { |r| r[:first_air] }
    if dated.size > 1
      order = dated.map { |r| safe_join([stats_series_link(r), " (#{r[:first_air].year})"]) }
      qas << faq_qa("In what order should I watch the Naked and Afraid series?",
                    safe_join(["In order of first airing: ", html_sentence(order), "."]))
    end

    if stats[:countries_count].positive?
      top = stats[:top_countries].map { |country, n| link_to(country, by_country_episodes_path(country)) }
      qas << faq_qa("Where was Naked and Afraid filmed?",
                    safe_join(["Episodes in our guide were filmed in #{pluralize(stats[:countries_count], 'country', 'countries')}",
                               (top.any? ? safe_join([", most often ", html_sentence(top)]) : ""), "."]))
    end
    qas
  end

  # ---------- episode pages ----------

  # "Naked and Afraid Shipwrecked Season 1 Episode 1: Abandon Ship"
  def episode_page_heading_phrase(episode)
    season = episode.season
    series = display_series_name(season&.series)
    [series, ("Season #{season.number}" if season&.number), ("Episode #{episode.number_in_season}" if episode.number_in_season)].compact.join(" ")
  end

  def episode_page_title(episode)
    phrase = episode_page_heading_phrase(episode)
    title  = episode.title.presence
    site_title(title ? "#{phrase}: #{title}" : phrase)
  end

  def episode_page_description(episode)
    loc    = episode.location
    place  = [loc&.region.to_s.strip.presence || loc&.site.to_s.strip.presence, loc&.country.to_s.strip.presence].compact.join(", ").presence
    prefix = "#{episode_page_heading_phrase(episode)}"
    prefix += " aired #{short_date(episode.air_date)}" if episode.air_date
    prefix += " in #{place}" if place
    prefix += "."
    synopsis = episode.synopsis_text
    return truncate_at_word("#{prefix} Participants, PSR, days lasted and items.", SeoHelper::DESCRIPTION_LIMIT) if synopsis.blank?
    truncate_at_word("#{prefix} #{synopsis}", SeoHelper::DESCRIPTION_LIMIT)
  end

  # "Naked and Afraid Shipwrecked · Season 1 · Episode 1 · Aired Jul 22, 2022" as parts.
  def episode_subtitle_parts(episode)
    season = episode.season
    [display_series_name(season&.series), ("Season #{season.number}" if season&.number),
     ("Episode #{episode.number_in_season}" if episode.number_in_season),
     ("Aired #{short_date(episode.air_date)}" if episode.air_date)].compact
  end

  # ~160-char plain-text excerpt of an episode synopsis for recap lists; nil when none.
  def episode_excerpt(episode, limit: 160)
    plain = episode.synopsis_text
    plain.present? ? truncate_at_word(plain, limit) : nil
  end
end
