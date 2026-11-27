# View helpers for the localized episode-guide pages (EpisodeGuidesController). Copy comes
# from config/locales/landing_<lang>.yml via an explicit locale; I18n.locale itself is
# never switched. A missing key raises, and a test keeps the three files in step.
module EpisodeGuidesHelper
  # Translate landing.guide.<key> into `lang` (defaults to the page's @lang).
  def landing_t(key, lang: @lang, **opts)
    I18n.t("landing.guide.#{key}", locale: lang.to_sym, raise: true, **opts)
  end

  def landing_count(key, count, lang: @lang)
    landing_t(key, count: count, lang: lang)
  end

  # "A, B y C" using the language's own "and" (Array#to_sentence would use English).
  def landing_list(items, lang: @lang)
    items = Array(items).map(&:to_s)
    return items.first.to_s if items.size <= 1
    "#{items[0..-2].join(', ')} #{landing_t(:and_word, lang: lang)} #{items.last}"
  end

  def landing_date(date, lang: @lang)
    month = landing_t(:months, lang: lang)[date.month - 1]
    key = date.day == 1 && I18n.exists?("landing.guide.date_first", locale: lang.to_sym) ? :date_first : :date
    landing_t(key, lang: lang, day: date.day, month: month, year: date.year)
  end

  # "Naked and Afraid Temporada 3": series name (a proper noun) + the localized word.
  def landing_season_label(season, lang: @lang)
    "#{season.series&.name} #{landing_t(:table_season, lang: lang)} #{season.number}"
  end

  def episode_guide_title(lang = @lang)
    site_title(landing_t(:html_title, lang: lang))
  end

  def episode_guide_description(guide, lang = @lang)
    text = landing_t(:description, lang: lang,
                     seasons: landing_count(:seasons, guide.season_count, lang: lang),
                     episodes: landing_count(:episodes, guide.episode_count, lang: lang),
                     series: landing_count(:series, guide.series_count, lang: lang))
    truncate_at_word(text, SeoHelper::DESCRIPTION_LIMIT)
  end

  # <link rel="alternate" hreflang> set: every guide language, plus x-default pointing at
  # the English series index. Every language page renders the same full set (so each pair
  # links back to the other), self-reference included.
  def episode_guide_alternates
    base = request.base_url
    alternates = EpisodeGuides::PATHS.map { |lang, path| { hreflang: lang, href: "#{base}#{path}" } }
    alternates << { hreflang: "x-default", href: "#{base}#{EpisodeGuides::DEFAULT_PATH}" }
  end

  def episode_guide_hreflang_tags
    safe_join(episode_guide_alternates.map { |a| tag.link(rel: "alternate", hreflang: a[:hreflang], href: a[:href]) }, "\n")
  end

  # {q:, a:, a_html:} pairs answered from the database. The visible FAQ and the FAQPage
  # JSON-LD both use these.
  def episode_guide_faq_qas(guide, lang = @lang)
    qas = []
    seasons  = landing_count(:seasons, guide.season_count, lang: lang)
    episodes = landing_count(:episodes, guide.episode_count, lang: lang)
    series   = landing_count(:series, guide.series_count, lang: lang)
    qas << { q: landing_t(:faq_total_q, lang: lang),
             a: landing_t(:faq_total_a, lang: lang, seasons: seasons, episodes: episodes, series: series) }

    if guide.place_count.positive?
      a = landing_t(:faq_where_a, lang: lang,
                    places: landing_count(:places, guide.place_count, lang: lang),
                    top: landing_list(guide.top_places, lang: lang))
      qas << { q: landing_t(:faq_where_q, lang: lang), a: a,
               a_html: safe_join([a, " ", link_to(landing_t(:faq_where_link, lang: lang), locations_path)]) }
    end

    if guide.latest_season && guide.latest_date
      a = landing_t(:faq_latest_a, lang: lang,
                    season: landing_season_label(guide.latest_season, lang: lang),
                    date: landing_date(guide.latest_date, lang: lang))
      qas << { q: landing_t(:faq_latest_q, lang: lang), a: a,
               a_html: safe_join([a, " ", link_to(landing_t(:faq_latest_link, lang: lang), latest_seasons_path)]) }
    end
    qas
  end

  def episode_guide_jsonld(guide, qas:, lang: @lang)
    base = request.base_url
    items = guide.rows.each_with_index.map do |row, i|
      { "@type" => "ListItem", "position" => i + 1, "name" => row.series.name.to_s,
        "url" => "#{base}#{series_path(row.series)}" }
    end
    [
      { "@context" => "https://schema.org", "@type" => "CollectionPage", "inLanguage" => lang,
        "name" => landing_t(:h1, lang: lang), "url" => canonical_request_url,
        "description" => episode_guide_description(guide, lang) },
      { "@context" => "https://schema.org", "@type" => "ItemList", "name" => landing_t(:h1, lang: lang),
        "numberOfItems" => items.size, "itemListElement" => items },
      breadcrumb_jsonld([
        { name: landing_t(:breadcrumb_home, lang: lang), path: root_path },
        { name: landing_t(:h1, lang: lang), path: EpisodeGuides.path(lang) }
      ]),
      { "@context" => "https://schema.org", "@type" => "FAQPage", "inLanguage" => lang,
        "mainEntity" => qas.map { |qa|
          { "@type" => "Question", "name" => qa[:q],
            "acceptedAnswer" => { "@type" => "Answer", "text" => qa[:a].to_s } } } }
    ]
  end
end
