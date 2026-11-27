# Everything /seasons/latest shows, computed from the episodes' air dates (nothing about what
# "has or has not been announced" is stated: only what is in the database, relative to today).
#
#   * per series, its latest season = the one with the newest air date (a season with only a
#     future-dated episode counts); a series is "active" when that date is within the last
#     ACTIVE_DAYS days or still ahead. If no series is active, the single most recent one is shown.
#   * next episode: the earliest episode dated today or later.
#   * last aired episode: the newest episode dated before today (an episode dated today is
#     "airs today", not yet counted as aired).
#   * this week: episodes dated Monday..Sunday of the current week.
#
# "Today" is Date.current (the app's time zone, Central), passed in so tests can pin it.
# Only the season plan (a handful of ids and dates) is cached, for ten minutes; records are
# always loaded fresh.
class LatestSeasonGuide
  ACTIVE_DAYS = 365
  CACHE_TTL   = 10.minutes

  # status of one episode relative to today
  UPCOMING = :upcoming
  TODAY    = :today
  AIRED    = :aired

  Entry = Struct.new(:series, :season, :episodes, :first_air, :last_air, keyword_init: true)

  Result = Struct.new(:today, :active, :others, :next_episode, :last_aired_episode, :week_range, :week_episodes,
                      keyword_init: true)

  def self.status(air_date, today)
    return nil unless air_date
    return UPCOMING if air_date > today
    air_date == today ? TODAY : AIRED
  end

  def self.call(today: Date.current) = new(today).call

  def initialize(today)
    @today = today
  end

  def call
    plan = Rails.cache.fetch(["latest_season_guide/plan/v1", @today.iso8601], expires_in: CACHE_TTL) { build_plan }
    seasons  = Season.where(id: plan.map { |p| p[:season_id] }).includes(:series).index_by(&:id)
    episodes = Episode.where(season_id: seasons.keys).includes(:location)
                      .order(Arel.sql("number_in_season ASC NULLS LAST, id ASC")).group_by(&:season_id)

    entries = plan.filter_map do |p|
      season = seasons[p[:season_id]] or next
      [p[:active], Entry.new(series: season.series, season: season, episodes: episodes[season.id] || [],
                             first_air: p[:first_air], last_air: p[:last_air])]
    end

    week = @today.beginning_of_week..@today.end_of_week
    Result.new(
      today: @today,
      active: entries.select(&:first).map(&:last),
      others: entries.reject(&:first).map(&:last),
      next_episode: scope.where("episodes.air_date >= ?", @today).order(Arel.sql("episodes.air_date ASC, episodes.id ASC")).first,
      last_aired_episode: scope.where("episodes.air_date < ?", @today).order(Arel.sql("episodes.air_date DESC, episodes.id DESC")).first,
      week_range: week,
      week_episodes: scope.where(air_date: week).order(Arel.sql("episodes.air_date ASC, episodes.id ASC")).to_a
    )
  end

  private

  def scope
    Episode.includes(:location, season: :series)
  end

  # One row per series (its season with the newest air date), newest first; each flagged
  # active or not. Plain values only, so it caches.
  def build_plan
    rows = Season.joins(:episodes).where.not(episodes: { air_date: nil })
                 .group("seasons.id", "seasons.series_id", "seasons.number")
                 .pluck("seasons.id", "seasons.series_id", "seasons.number",
                        Arel.sql("MIN(episodes.air_date)"), Arel.sql("MAX(episodes.air_date)"))
    best = rows.group_by { |r| r[1] }.values.map { |rs| rs.max_by { |r| [r[4], r[2]] } }
    newest_first = best.sort_by { |r| [r[4], r[1]] }.reverse
    cutoff = @today - ACTIVE_DAYS
    active_ids = newest_first.select { |r| r[4] >= cutoff }.map(&:first)
    active_ids = newest_first.first(1).map(&:first) if active_ids.empty?
    newest_first.map do |season_id, _series_id, _number, first_air, last_air|
      { season_id: season_id, first_air: first_air, last_air: last_air, active: active_ids.include?(season_id) }
    end
  end
end
