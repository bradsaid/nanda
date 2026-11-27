# Facts about a set of episodes (one season, or every season of a series), computed
# only from what is stored: air dates, locations, scheduled days, appearances.
# Nothing here is guessed; every reader returns nil / [] when the data is missing so
# the views can leave that statistic out instead of showing zero or a blank.
#
# `episodes` must come in display order with `location` and `appearances: :survivor`
# preloaded (SeasonsController#show and SeriesController#show do that); the readers
# below never query, except #brought_items, which runs one grouped query on demand.
class EpisodeSetOverview
  TOP_PSR_NAMES   = 3
  WEIGHT_LOSS_CAP = 50

  ResultSummary = Struct.new(:recorded, :survivor_total, :completed, :tapped_out, :medical, :eliminated, keyword_init: true)

  attr_reader :episodes

  def initialize(episodes)
    @episodes = episodes.to_a
  end

  def episode_count = episodes.size

  # --- dates -------------------------------------------------------------------------

  def air_dates = @air_dates ||= episodes.filter_map(&:air_date)
  def premiere  = air_dates.min
  def finale    = air_dates.max

  # [2021] or [2021, 2022]: the calendar years the episodes aired in.
  def air_years = air_dates.map(&:year).uniq.sort

  # "2021" / "2021–2022"
  def years_label
    years = air_years
    return nil if years.empty?
    years.size == 1 ? years.first.to_s : "#{years.first}–#{years.last}"
  end

  # --- places ------------------------------------------------------------------------

  def locations = @locations ||= episodes.filter_map(&:location)

  # Distinct countries, in the order the episodes reach them.
  def countries = @countries ||= locations.filter_map { |l| l.country.to_s.strip.presence }.uniq

  # [[label, episode_count]] for each distinct filming location, busiest first.
  # label is "site, region, country" with the blanks left out.
  def location_counts
    @location_counts ||= locations.group_by(&:id).values
                                  .map { |ls| [self.class.location_label(ls.first), ls.size, ls.first] }
                                  .reject { |label, _, _| label.blank? }
                                  .sort_by { |label, n, _| [-n, label] }
  end

  def self.location_label(location)
    [location.site, location.region, location.country].map { |p| p.to_s.strip }.reject(&:blank?).join(", ")
  end

  # --- format ------------------------------------------------------------------------

  def scheduled_days = @scheduled_days ||= episodes.filter_map { |e| e.scheduled_days if e.scheduled_days.to_i.positive? }.uniq.sort

  # The participant arrangements recorded ("2+2", "3+3+3+3", "Group"), most common first.
  def arrangements
    @arrangements ||= episodes.filter_map { |e| e.participant_arrangement.to_s.strip.presence }
                              .tally.sort_by { |a, n| [-n, a] }.map(&:first)
  end

  # How many teams the arrangement says there are, only when at least one episode has
  # a numeric arrangement with several teams ("2+2+2+2+2+2+2" = 7). nil otherwise.
  def team_count
    @team_count ||= begin
      counts = episodes.select { |e| e.team_count_known? && e.multi_team? }.map(&:team_count)
      counts.max
    end
  end

  def team_arrangement
    return nil unless team_count
    episodes.find { |e| e.team_count_known? && e.multi_team? && e.team_count == team_count }&.participant_arrangement.to_s.strip.presence
  end

  # --- cast --------------------------------------------------------------------------

  def appearances = @appearances ||= episodes.flat_map { |e| e.appearances.to_a }

  def survivors = @survivors ||= appearances.filter_map(&:survivor).uniq.sort_by { |s| s.full_name.to_s.downcase }

  # Who is on each episode, for the "partners" list of non-continuous seasons:
  # [[episode, [survivor, ...]]] for the episodes that have a cast.
  def pairings
    @pairings ||= episodes.filter_map do |e|
      cast = e.appearances.filter_map(&:survivor).uniq
      [e, cast] if cast.any?
    end
  end

  # --- results -----------------------------------------------------------------------

  # What is on record about how each survivor's run ended, or nil when no appearance has a
  # result at all (results exist for only a fraction of the appearances). A survivor with
  # several appearances counts once, by the latest appearance that has a result.
  def results
    return @results if defined?(@results)
    latest = {}
    episodes.each do |e|
      e.appearances.each do |a|
        next if a.result.blank? || a.survivor.nil?
        latest[a.survivor] = a.result
      end
    end
    @results = if latest.empty?
      nil
    else
      by_result = latest.group_by { |_, r| r }.transform_values { |pairs| pairs.map(&:first).sort_by { |s| s.full_name.to_s.downcase } }
      ResultSummary.new(
        recorded:       latest.size,
        survivor_total: survivors.size,
        completed:      by_result.fetch("success", []),
        tapped_out:     by_result.fetch("tap_out", []) + by_result.fetch("medical_tap_out", []),
        medical:        by_result.fetch("medical_tap_out", []),
        eliminated:     by_result.fetch("elimination", [])
      )
    end
  end

  # --- PSR ---------------------------------------------------------------------------

  # { value: BigDecimal, survivors: [..] } for the highest ending PSR on record.
  def top_psr
    return @top_psr if defined?(@top_psr)
    rated = appearances.select { |a| a.ending_psr && a.survivor }
    @top_psr = if rated.empty?
      nil
    else
      best = rated.map(&:ending_psr).max
      { value: best, survivors: rated.select { |a| a.ending_psr == best }.map(&:survivor).uniq.first(TOP_PSR_NAMES) }
    end
  end

  def self.format_psr(value)
    return nil if value.nil?
    value = value.to_f
    (value % 1).zero? ? value.to_i.to_s : format("%.1f", value).sub(/0\z/, "")
  end

  # --- weight loss -------------------------------------------------------------------

  # Rows { survivor:, episode:, value: } for appearances that have a weight_loss, largest
  # first. Empty (so the table is not rendered) when none do.
  def weight_loss_rows
    @weight_loss_rows ||= episodes.flat_map do |e|
      e.appearances.filter_map do |a|
        next if a.weight_loss.nil? || a.survivor.nil?
        { survivor: a.survivor, episode: e, value: a.weight_loss }
      end
    end.sort_by { |r| [-r[:value], r[:survivor].full_name.to_s.downcase] }
  end

  def weight_loss_recorded? = weight_loss_rows.any?

  # --- items -------------------------------------------------------------------------

  # [[item, number of survivalists who brought it]] for the items brought most, only when
  # at least one was brought by 2+ people (a list of all-ones is noise). One grouped query.
  def brought_items(limit: 5)
    @brought_items ||= begin
      ids = appearances.map(&:id)
      if ids.empty?
        []
      else
        counts = AppearanceItem.brought.where(appearance_id: ids)
                               .group(:item_id)
                               .order(Arel.sql("COUNT(DISTINCT appearance_items.appearance_id) DESC, appearance_items.item_id ASC"))
                               .limit(limit)
                               .distinct.count(:appearance_id)
        if counts.values.max.to_i < 2
          []
        else
          items = Item.where(id: counts.keys).index_by(&:id)
          counts.filter_map { |id, n| [items[id], n] if items[id] }
        end
      end
    end
  end
end
