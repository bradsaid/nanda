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

    @active_survivors =
      Survivor.joins(:appearances)
              .group("survivors.id")
              .order(Arel.sql("MAX(appearances.created_at) DESC"))
              .limit(6)

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
