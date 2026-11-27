# Everything the localized episode-guide pages show, straight from the database:
# series -> seasons (with episode count, year and filming countries) plus site totals.
# No text lives here; the pages translate the labels around these values.
class EpisodeGuideData
  SeasonRow = Struct.new(:season, :number, :year, :episode_count, :places, keyword_init: true)
  SeriesRow = Struct.new(:series, :seasons, :episode_count, keyword_init: true)
  Result = Struct.new(:rows, :season_count, :episode_count, :series_count,
                      :place_count, :top_places, :latest_season, :latest_date, keyword_init: true)

  TOP_PLACES = 5

  def self.call(today: Date.current)
    new(today).call
  end

  def initialize(today)
    @today = today
  end

  def call
    seasons  = Season.includes(:series).to_a
    episodes = Episode.left_joins(:location).pluck(:season_id, :air_date, "locations.country")

    by_season = episodes.group_by(&:first)
    place_counts = Hash.new(0)

    rows = seasons.group_by(&:series).filter_map do |series, list|
      season_rows = list.sort_by { |s| [s.number || 0, s.id] }.filter_map do |season|
        eps = by_season[season.id] || []
        next if eps.empty?
        eps.each { |_, _, country| place_counts[country.strip] += 1 if country.present? }
        dates = eps.filter_map { |_, date, _| date }
        SeasonRow.new(
          season: season,
          number: season.number,
          year: season.year || dates.min&.year,
          episode_count: eps.size,
          places: eps.filter_map { |_, _, c| c&.strip.presence }.tally.sort_by { |name, n| [-n, name] }.map(&:first)
        )
      end
      next if season_rows.empty?
      SeriesRow.new(series: series, seasons: season_rows, episode_count: season_rows.sum(&:episode_count))
    end
    rows = rows.sort_by { |r| r.series.name.to_s.downcase }

    aired = episodes.select { |_, date, _| date && date <= @today }
    latest = aired.max_by { |_, date, _| date }
    latest_season = latest && seasons.find { |s| s.id == latest[0] }

    Result.new(
      rows: rows,
      season_count: rows.sum { |r| r.seasons.size },
      episode_count: rows.sum(&:episode_count),
      series_count: rows.size,
      place_count: place_counts.size,
      top_places: place_counts.sort_by { |name, n| [-n, name] }.first(TOP_PLACES).map(&:first),
      latest_season: latest_season,
      latest_date: latest && latest[1]
    )
  end
end
