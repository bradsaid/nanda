class HomeController < ApplicationController
  def index
    @counts = {
      series:    Series.count,
      seasons:   Season.count,
      episodes:  Episode.count,
      survivors: Survivor.count,
      items:     Item.count,
      locations: Location.distinct.count(:country)
    }

    @latest_episode =
      Episode
        .includes(:location, season: :series)
        .order(Arel.sql("air_date IS NULL, air_date DESC"))
        .first

    @top_items_brought =
      AppearanceItem.where(source: "brought")
        .joins(:item)
        .group("items.id", "items.name")
        .select("items.id, items.name, SUM(appearance_items.quantity) AS total")
        .order("total DESC").limit(5)

    @top_items_given =
      AppearanceItem.where(source: "given")
        .joins(:item)
        .group("items.id", "items.name")
        .select("items.id, items.name, SUM(appearance_items.quantity) AS total")
        .order("total DESC").limit(5)

    @recent_episodes =
      Episode.includes(:location, season: :series)
             .order(Arel.sql("air_date IS NULL, air_date DESC"))
             .limit(5)

    # "Recently Active" = survivors who appeared in the most recently aired
    # episode, filtered to those still active (drop anyone with a result-
    # bearing appearance earlier in the same season — they're already out).
    latest_ep = Episode.where.not(air_date: nil)
                       .where("air_date <= ?", Date.current)
                       .order(air_date: :desc, id: :desc)
                       .first
    if latest_ep
      latest_ep_appearances = latest_ep.appearances.includes(:survivor).to_a
      exit_air_dates = Appearance.joins(:episode)
                                 .where("episodes.season_id = ?", latest_ep.season_id)
                                 .where(survivor_id: latest_ep_appearances.map(&:survivor_id))
                                 .where.not(result: nil)
                                 .group(:survivor_id)
                                 .minimum("episodes.air_date")
      # "Active" = no result-bearing appearance yet on or before this episode.
      # A survivor eliminated / tapped out / completed in the latest episode
      # itself is also dropped, since they're no longer currently in a
      # challenge.
      active_ids = latest_ep_appearances.reject { |a|
        d = exit_air_dates[a.survivor_id]
        d && d <= latest_ep.air_date
      }.map(&:survivor_id)
      @active_survivors = Survivor.where(id: active_ids)
                                  .with_attached_avatar
                                  .order(:full_name)
    else
      @active_survivors = Survivor.none
    end

    @top_countries =
      Episode.joins(:location)
             .group("locations.country")
             .order(Arel.sql("COUNT(*) DESC"))
             .limit(5).count

    # Per-country challenge counts using the same continuous-story dedupe used
    # on the Locations index: one challenge per episode for standard seasons,
    # and one per (season, location) pair for continuous-story seasons/series.
    non_cont_by_country = Episode.joins(:location, season: :series)
                                 .where("COALESCE(seasons.continuous_story, false) = false AND COALESCE(series.continuous_story, false) = false")
                                 .where.not(locations: { country: [nil, ""] })
                                 .group("locations.country").count
    cont_by_country = Episode.joins(:location, season: :series)
                             .where("COALESCE(seasons.continuous_story, false) = true OR COALESCE(series.continuous_story, false) = true")
                             .where.not(locations: { country: [nil, ""] })
                             .distinct.pluck("locations.country", :season_id, :location_id)
                             .group_by(&:first).transform_values(&:size)
    @challenges_by_country = non_cont_by_country.merge(cont_by_country) { |_k, a, b| a + b }

    # 🔽 Sort Top Survivors by COLLAPSED, but also select TOTAL so the view can show both
    @top_survivors =
      Survivor
        .left_joins(appearances: { episode: { season: :series } })
        .joins(appearance_exits_join)
        .select([
          "survivors.*",
          episodes_total_capped_sql("episodes_total_count"),
          collapsed_episodes_sql("episodes_collapsed_count")
        ].join(", "))
        .group("survivors.id")
        .order("episodes_collapsed_count DESC, episodes_total_count DESC, survivors.full_name ASC")
        .limit(6)
  end


end
