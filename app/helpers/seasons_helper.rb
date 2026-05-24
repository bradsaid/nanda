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
end