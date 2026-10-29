class HomeController < ApplicationController
  include GearShelf

  # The headline numbers and per-country tallies are plain hashes of integers
  # that only move when someone edits an episode, yet were recomputed (nine
  # queries, two of them joins over every episode) on every home-page view.
  AGGREGATES_TTL = 10.minutes

  # The home page only features products with credible evidence; "Similar" stand-ins live deeper in the site.
  HOME_MATCHES = %w[confirmed].freeze

  def index
    @counts, @top_countries, @challenges_by_country =
      Rails.cache.fetch("home/aggregates/v1", expires_in: AGGREGATES_TTL) { home_aggregates }

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

    build_home_shop_shelf

    @recent_episodes =
      Episode.includes(:location, season: :series)
             .order(Arel.sql("air_date IS NULL, air_date DESC"))
             .limit(5)

    # "Recently Active" = survivors ordered by the air date of their most
    # recent appearance. Whoever was on screen most recently leads.
    @active_survivors =
      Survivor.joins(appearances: :episode)
              .where.not(episodes: { air_date: nil })
              .where("episodes.air_date <= ?", Date.current)
              .with_attached_avatar
              .group("survivors.id")
              .order(Arel.sql("MAX(episodes.air_date) DESC, survivors.full_name ASC"))
              .limit(12)

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

  private

  # Featured gear: what was used in the latest episode when the catalog has products for
  # it; otherwise the gear survivors bring most, so the home page always has a shelf.
  def build_home_shop_shelf
    if @latest_episode
      build_gear_shelf(label: "Seen in the latest episode", episodes: [@latest_episode], max_groups: 3, limit: 2, matches: HOME_MATCHES) do |scope|
        scope.where(episodes: { id: @latest_episode.id })
      end
      @shop_heading = "Gear From the Latest Episode"
    end
    return if @shop_shelf && !@shop_shelf.empty?

    ids = Rails.cache.fetch("home/top-brought-item-ids/v1", expires_in: AGGREGATES_TTL) do
      AppearanceItem.where(source: "brought").group(:item_id).order(Arel.sql("SUM(quantity) DESC")).limit(25).pluck(:item_id)
    end
    by_id = Item.where(id: ids).index_by(&:id)
    items = ids.filter_map { |id| by_id[id] }
    @shop_shelf = ShopShelf.build(holders: items.index_with { [] }, rank: items.each_with_index.to_h { |item, i| [item, items.size - i] },
                                  max_groups: 3, limit: 2, matches: HOME_MATCHES)
    @shop_links = ShopLinks.build(@shop_shelf.products)
    @shop_heading = "Gear Survivors Bring Most"
  end

  def home_aggregates
    counts = {
      series:    Series.count,
      seasons:   Season.count,
      episodes:  Episode.count,
      survivors: Survivor.count,
      items:     Item.count,
      locations: Location.distinct.count(:country)
    }

    top_countries =
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
    challenges_by_country = non_cont_by_country.merge(cont_by_country) { |_k, a, b| a + b }

    [counts, top_countries, challenges_by_country]
  end
end
