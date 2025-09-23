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

    # 🔽 Sort Top Survivors by COLLAPSED, but also select TOTAL so the view can show both
    @top_survivors =
      Survivor
        .left_joins(appearances: { episode: { season: :series } })
        .select([
          "survivors.*",
          "COUNT(DISTINCT episodes.id) AS episodes_total_count",
          collapsed_episodes_sql("episodes_collapsed_count")
        ].join(", "))
        .group("survivors.id")
        .order("episodes_collapsed_count DESC, episodes_total_count DESC, survivors.full_name ASC")
        .limit(6)
  end


end
