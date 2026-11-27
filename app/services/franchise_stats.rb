# Franchise-wide numbers for the /seasons and /series guides: totals, the first and most
# recently aired episode, and one row per series in order of first airing. Everything is
# computed from the tables (nothing hard-coded), in a handful of aggregate queries, and
# cached as plain hashes keyed by the tables' counts and newest updated_at, so any edit
# to a series, season, episode or location rebuilds it and an idle site never recomputes.
class FranchiseStats
  CACHE_VERSION = 1
  TOP_COUNTRIES = 5

  def self.fetch
    Rails.cache.fetch(cache_key, expires_in: 12.hours) { new.compute }
  end

  def self.cache_key
    stamp = ->(model) { model.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(updated_at)")).then { |n, t| [n, t&.utc&.to_f] } }
    ["franchise_stats", CACHE_VERSION, *[Series, Season, Episode, Location].map(&stamp)].flatten
  end

  def compute
    series_rows = Series.left_joins(seasons: { episodes: :location })
                        .group("series.id", "series.name")
                        .pluck("series.id", "series.name",
                               Arel.sql("COUNT(DISTINCT seasons.id)"),
                               Arel.sql("COUNT(DISTINCT episodes.id)"),
                               Arel.sql("MIN(episodes.air_date)"),
                               Arel.sql("COUNT(DISTINCT NULLIF(TRIM(locations.country), ''))"))
                        .map do |id, name, seasons, episodes, first_air, countries|
      { id: id, name: name, seasons: seasons.to_i, episodes: episodes.to_i, first_air: first_air, countries: countries.to_i }
    end
    # Order of first airing; a series with no dated episode goes last.
    series_rows.sort_by! { |r| [r[:first_air] ? 0 : 1, r[:first_air] || Date.new(9999, 1, 1), r[:name].to_s.downcase] }

    # The flagship is the series named exactly "Naked and Afraid"; failing that, the one aired first.
    flagship = series_rows.find { |r| r[:name].to_s.strip.casecmp?("Naked and Afraid") } || series_rows.find { |r| r[:first_air] }

    country_rows = Episode.joins(:location)
                          .where.not(locations: { country: [nil, ""] })
                          .group("locations.country")
                          .order(Arel.sql("COUNT(*) DESC, locations.country ASC"))
                          .limit(TOP_COUNTRIES)
                          .count

    {
      series:          series_rows,
      flagship_id:     flagship&.dig(:id),
      total_series:    series_rows.size,
      total_seasons:   series_rows.sum { |r| r[:seasons] },
      total_episodes:  series_rows.sum { |r| r[:episodes] },
      countries_count: Location.joins(:episodes).where.not(country: [nil, ""]).distinct.count(:country),
      top_countries:   country_rows.to_a,
      first_aired:     aired_marker(Episode.where.not(air_date: nil).order(:air_date, :id)),
      last_aired:      aired_marker(Episode.where("air_date <= ?", Date.current).order(air_date: :desc, id: :desc))
    }
  end

  private

  def aired_marker(scope)
    ep = scope.includes(season: :series).first
    return nil unless ep
    { date: ep.air_date, title: ep.title, episode_param: ep.to_param, number_in_season: ep.number_in_season,
      season_id: ep.season_id, season_number: ep.season&.number, series_name: ep.season&.series&.name }
  end
end
