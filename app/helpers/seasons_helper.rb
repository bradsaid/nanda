module SeasonsHelper
  SERVICE_LABELS = {
    discovery_plus: "Discovery+",
    max:            "Max",
    hulu:           "Hulu",
    disney_plus:    "Disney+",
    netflix:        "Netflix",
    prime_video:    "Prime Video",
    discovery_go:   "Discovery GO"
  }.freeze

  SERIES_SYNOPSES = {
    "Naked and Afraid"                    => "The original series. Two strangers, naked and alone, get dropped into a remote, unforgiving environment for a 21-day primitive survival challenge with nothing but one personal item each.",
    "Naked and Afraid: Solo"              => "A solo spin-off. Individual survivalists face 21 days of wilderness alone, with no partner or team.",
    "Naked and Afraid XL"                 => "Extended-format spin-off pitting a group of returning, battle-tested survivalists against the wild for 40 days, or 60 in later runs.",
    "Naked and Afraid: Alone"             => "Veteran cast members take on solo challenges across multiple remote locations. Each survivalist faces the wilderness entirely on their own.",
    "Naked And Afraid Savage"             => "Returning survivalists pushed into the most savage and unforgiving environments the franchise has ever filmed.",
    "Naked and Afraid Castaways"          => "Survivalists are stranded on remote islands without preselected partners. They have to find each other, organize, and survive as a group.",
    "Naked and Afraid Last One Standing"  => "Elimination-style competition. Survivalists compete head to head in the wild, and the last person to tap out wins a $100,000 prize.",
    "Naked and Afraid Apocalypse"         => "A post-apocalyptic scenario test. Survivalists tackle a 35-day challenge in a wasteland staged to mimic end-of-the-world conditions.",
    "Naked and Afraid: Global Showdown"   => "Seven international teams of two compete in a 40-day, points-based survival tournament for a $200,000 prize. Each team represents a different region of the world."
  }.freeze

  def streaming_label(key)
    SERVICE_LABELS[key.to_sym] || key.to_s.titleize
  end

  def series_synopsis(series)
    return nil unless series
    SERIES_SYNOPSES[series.name]
  end

  # { "Series Name" => { season_number => { service => url } } }
  def self.season_services
    @season_services ||= begin
      {
        "Naked and Afraid" => begin
          h = {}
          (1..19).each { |n| h[n] = { discovery_plus: "https://www.discoveryplus.com/" } }
          [4, 5, 11, 12, 14].each   { |n| h[n][:disney_plus]  = "https://www.disneyplus.com/" }
          [4, 5, 7, 11, 12, 14, 18].each { |n| h[n][:hulu]    = "https://www.hulu.com/" }
          [18, 19].each             { |n| h[n][:max]          = "https://play.hbomax.com/" }
          [17, 18].each             { |n| h[n][:discovery_go] = "https://go.discovery.com/" }
          h
        end,
        "Naked and Afraid: Solo" => {
          1 => { discovery_plus: "https://www.discoveryplus.com/",
                 discovery_go:   "https://go.discovery.com/" }
        },
        "Naked and Afraid XL" => begin
          h = {}
          (1..10).each { |n| h[n] = { discovery_plus: "https://www.discoveryplus.com/" } }
          h[4][:disney_plus]   = "https://www.disneyplus.com/"
          h[4][:hulu]          = "https://www.hulu.com/"
          [9, 10].each { |n| h[n][:discovery_go] = "https://go.discovery.com/" }
          h
        end,
        "Naked and Afraid: Alone" => {
          1 => { discovery_plus: "https://www.discoveryplus.com/",
                 discovery_go:   "https://go.discovery.com/" }
        },
        "Naked And Afraid Savage" => begin
          h = {}
          (1..2).each { |n| h[n] = { discovery_plus: "https://www.discoveryplus.com/" } }
          h[2][:discovery_go] = "https://go.discovery.com/"
          h
        end,
        "Naked and Afraid Castaways" => {
          1 => { discovery_plus: "https://www.discoveryplus.com/",
                 disney_plus:    "https://www.disneyplus.com/",
                 hulu:           "https://www.hulu.com/",
                 discovery_go:   "https://go.discovery.com/" }
        },
        "Naked and Afraid Last One Standing" => begin
          h = {}
          (1..3).each { |n| h[n] = { discovery_plus: "https://www.discoveryplus.com/" } }
          h[3][:hulu]         = "https://www.hulu.com/"
          h[3][:max]          = "https://play.hbomax.com/"
          [2, 3].each { |n| h[n][:discovery_go] = "https://go.discovery.com/" }
          h
        end,
        "Naked and Afraid Apocalypse" => {
          1 => { discovery_plus: "https://www.discoveryplus.com/",
                 hulu:           "https://www.hulu.com/",
                 max:            "https://play.hbomax.com/" }
        },
        "Naked and Afraid: Global Showdown" => {
          1 => { discovery_go: "https://go.discovery.com/" }
        }
      }.freeze
    end
  end

  def services_for(series_name, season_number)
    SeasonsHelper.season_services.dig(series_name, season_number.to_i) || {}
  end

  # Brief auto-generated synopsis of a season — survivor count, episode count,
  # locations (regular) or days + single location (continuous-story), plus any
  # special-format modifiers like Fan, Extended, Mentor.
  def season_synopsis(season, episodes: nil, survivor_count: nil)
    return nil unless season

    eps        = episodes || season.episodes.includes(:location).to_a
    return nil if eps.empty?

    ep_count   = eps.size
    surv_count = survivor_count || Appearance.joins(:episode)
                                              .where(episodes: { season_id: season.id })
                                              .distinct
                                              .count(:survivor_id)

    if season.continuous_story_effective?
      countries = eps.map { |ep| ep.location&.country }.compact_blank.uniq
      where     = countries.empty? ? "an undisclosed location" : countries.to_sentence
      days      = eps.map(&:scheduled_days).compact.max
      day_part  = days ? "#{days}-day " : ""
      "#{surv_count} survivalists attempt a #{day_part}continuous challenge in #{where}, chronicled across #{ep_count} #{'episode'.pluralize(ep_count)}."
    else
      countries = eps.map { |ep| ep.location&.country }.compact_blank.uniq
      where     = countries.empty? ? "various locations" : countries.to_sentence
      base      = "#{surv_count} survivalists test their survival skills across #{ep_count} #{'episode'.pluralize(ep_count)} filmed in #{where}."

      mod_tokens = eps.flat_map do |ep|
        ep.type_modifiers.to_s.split(",").map(&:strip).reject(&:empty?)
      end
      return base if mod_tokens.empty?

      mod_counts  = mod_tokens.tally.sort_by { |_, c| -c }
      if mod_tokens.size == 1
        label = mod_counts.first.first
        article = label.to_s.match?(/\A[AEIOUaeiou]/) ? "an" : "a"
        "#{base} Includes #{article} #{label} challenge episode."
      else
        mod_phrases = mod_counts.map { |label, count| count > 1 ? "#{count} #{label}" : label }
        "#{base} Includes #{mod_phrases.to_sentence} challenge episodes."
      end
    end
  end
end