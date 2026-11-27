# Wording, FAQ and structured data for /seasons/latest. Every sentence is built from the
# episodes in the database and today's date; nothing says what has or has not been announced.
module LatestSeasonsHelper
  LATEST_TITLE = "Latest Naked and Afraid Season: Episodes & Air Dates".freeze

  def latest_season_label(season)
    "#{season.series&.name} Season #{season.number}"
  end

  def episode_air_date_text(episode)
    episode.air_date.strftime("%B %-d, %Y")
  end

  # [css class, label] for an episode's status relative to the guide's "today".
  def episode_status_badge(episode, today)
    case LatestSeasonGuide.status(episode.air_date, today)
    when LatestSeasonGuide::UPCOMING then ["text-bg-info", "Upcoming"]
    when LatestSeasonGuide::TODAY    then ["text-bg-warning", "Airs today"]
    when LatestSeasonGuide::AIRED    then ["text-bg-secondary", "Aired"]
    end
  end

  # "Series Season 3, Episode 2": for FAQ sentences.
  def latest_episode_ref(episode)
    parts = [latest_season_label(episode.season)]
    parts << "Episode #{episode.number_in_season}" if episode.number_in_season
    parts.join(", ")
  end

  def latest_meta_description(guide)
    lead = guide.last_aired_episode&.season || guide.active.first&.season
    generic = "Every Naked and Afraid season and episode with air dates and filming locations, upcoming episodes marked, and quick answers about the latest season."
    return generic unless lead
    text = "Latest Naked and Afraid season in our database: #{latest_season_label(lead)}. Every episode with air date and location, upcoming episodes marked."
    text.length <= SeoHelper::DESCRIPTION_LIMIT ? text : generic
  end

  # {q:, a:, a_html:} pairs answered only from air dates in the database.
  def latest_season_faq_qas(guide)
    qas   = []
    today = guide.today

    if (ep = guide.last_aired_episode)
      season = ep.season
      latest_upcoming = guide.next_episode
      a = "The most recently aired season in our database is #{latest_season_label(season)}; its newest aired episode is dated #{episode_air_date_text(ep)}."
      a_html = safe_join(["The most recently aired season in our database is ", link_to(latest_season_label(season), season_path(season)),
                          "; its newest aired episode is dated #{episode_air_date_text(ep)}."])
      if latest_upcoming && latest_upcoming.season_id != season.id
        extra = " #{latest_season_label(latest_upcoming.season)} is also listed with an episode dated #{episode_air_date_text(latest_upcoming)}."
        a += extra
        a_html = safe_join([a_html, extra])
      end
      qas << { q: "What is the latest Naked and Afraid season?", a: a, a_html: a_html }

      qas << { q: "When was the most recent Naked and Afraid episode aired?",
               a: "The most recent episode in our database to have aired is \"#{ep.title}\" (#{latest_episode_ref(ep)}), dated #{episode_air_date_text(ep)}.",
               a_html: safe_join(["The most recent episode in our database to have aired is ", link_to("\"#{ep.title}\"", episode_path(ep)),
                                  " (#{latest_episode_ref(ep)}), dated #{episode_air_date_text(ep)}."]) }
    elsif (entry = guide.active.first)
      qas << { q: "What is the latest Naked and Afraid season?",
               a: "The most recent season in our database is #{latest_season_label(entry.season)}." }
    end

    week = guide.week_episodes
    week_label = "#{guide.week_range.first.strftime('%B %-d')} to #{guide.week_range.last.strftime('%B %-d')}"
    week_a =
      if week.any?
        list = week.map { |e| "\"#{e.title}\" (#{latest_season_label(e.season)}) #{e.air_date < today ? 'aired' : (e.air_date == today ? 'airs today' : 'is dated')} #{episode_air_date_text(e)}" }
        "Yes. In our database: #{list.to_sentence}."
      else
        tail = guide.last_aired_episode ? " The most recent episode that has aired is dated #{episode_air_date_text(guide.last_aired_episode)}." : ""
        "No episode in our database is dated this week (#{week_label}).#{tail}"
      end
    qas << { q: "Is there a new Naked and Afraid episode this week?", a: week_a }

    nxt = guide.next_episode
    qas << { q: "When is the next Naked and Afraid episode?",
             a: if nxt
                  "The next episode in our database is \"#{nxt.title}\" (#{latest_episode_ref(nxt)}), dated #{episode_air_date_text(nxt)}."
                else
                  "No upcoming episode is listed in our database right now. New seasons and episodes are added as soon as they are announced."
                end }
    qas
  end

  def latest_seasons_jsonld(guide, qas:)
    base = request.base_url
    episodes = guide.active.flat_map(&:episodes)
    items = episodes.each_with_index.map do |ep, i|
      { "@type" => "ListItem", "position" => i + 1, "url" => "#{base}#{episode_path(ep)}", "name" => ep.title.to_s }
    end
    [
      { "@context" => "https://schema.org", "@type" => "CollectionPage", "name" => LATEST_TITLE,
        "url" => canonical_request_url, "description" => latest_meta_description(guide) },
      { "@context" => "https://schema.org", "@type" => "ItemList", "name" => "Latest Naked and Afraid episodes",
        "numberOfItems" => items.size, "itemListElement" => items },
      breadcrumb_jsonld([
        { name: "Home", path: root_path },
        { name: "Seasons", path: seasons_path },
        { name: "Latest season", path: latest_seasons_path }
      ]),
      { "@context" => "https://schema.org", "@type" => "FAQPage",
        "mainEntity" => qas.map { |qa|
          { "@type" => "Question", "name" => qa[:q],
            "acceptedAnswer" => { "@type" => "Answer", "text" => (qa[:a_html].presence || qa[:a]).to_s } } } }
    ]
  end
end
