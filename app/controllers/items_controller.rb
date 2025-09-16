class ItemsController < ApplicationController
  def index
    @q       = params[:q].to_s.strip
    @country = params[:country].presence
    @limit   = (params[:limit].presence || 20).to_i.clamp(1, 200)

    @countries = Location.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)

    # Base (must join series for adjusted logic)
    ai = AppearanceItem.joins(:item, appearance: { episode: [:location, { season: :series }] })
    ai = ai.where("items.name ILIKE ?", "%#{@q}%") if @q.present?
    ai = ai.where(locations: { country: @country }) if @country.present?

    # Top lists (adjusted totals)
    @top_brought = ai.where(source: "brought")
                    .select("items.id, items.name, #{adjusted_total_sql}")           # alias => total
                    .group("items.id, items.name")
                    .order("total DESC").limit(@limit)

    @top_given   = ai.where(source: "given")
                    .select("items.id, items.name, #{adjusted_total_sql}")           # alias => total
                    .group("items.id, items.name")
                    .order("total DESC").limit(@limit)

    # Given in episodes (unique & adjusted)
    @given_in_episodes = ai
      .select("items.id, items.name, #{per_episode_presence_sql('total')}")
      .group("items.id, items.name")
      .order("total DESC")
      .limit(@limit)

    @given_in_episodes_adj = ai
      .select("items.id, items.name, #{collapsed_episode_presence_sql('total_adj')}")
      .group("items.id, items.name")
      .order("total_adj DESC")
      .limit(@limit)

    @rarest = ai
      .select([
        "items.id, items.name",
        adjusted_presence_sql(total_alias: "total"),
        adjusted_presence_for_source_sql("brought", total_alias: "brought_total"),
        adjusted_presence_for_source_sql("given",   total_alias: "given_total")
      ].join(", "))
      .group("items.id, items.name")
      .having("#{adjusted_presence_expr} > 0")
      .order("total ASC, items.name ASC")
      .limit(@limit)

    # Items per country (unique per episode) and adjusted
    rows = ai
      .select([
        "locations.country AS country",
        "items.id   AS item_id",
        "items.name AS item_name",
        per_episode_presence_sql("total")
      ].join(", "))
      .group("locations.country, items.id, items.name")
      .order("locations.country ASC, total DESC")

    @items_by_country = rows.group_by(&:country).transform_values { |arr| arr.first(10) }

    rows_adj = ai
      .select([
        "locations.country AS country",
        "items.id   AS item_id",
        "items.name AS item_name",
        collapsed_episode_presence_sql("total_adj")
      ].join(", "))
      .group("locations.country, items.id, items.name")
      .order("locations.country ASC, total_adj DESC")

    @items_by_country_adj = rows_adj.group_by(&:country).transform_values { |arr| arr.first(10) }


  end

  def show
    @item    = Item.find(params[:id])
    @country = params[:country].presence

    # Base scope with all joins needed (series join required for adjusted logic)
    scope = @item.appearance_items
                .joins(appearance: [{ episode: [:location, { season: :series }] }, :survivor])
                .includes(appearance: [:survivor, episode: [:season, :location]])

    scope = scope.where(locations: { country: @country }) if @country.present?

    # Split by source
    @brought_ai = scope.where(source: "brought")
                      .order("episodes.air_date NULLS LAST, survivors.full_name")
    @given_ai   = scope.where(source: "given")
                      .order("episodes.air_date NULLS LAST, survivors.full_name")


    @given_episode_ids   = @given_ai.reorder(nil).distinct.pluck("appearances.episode_id")
    @brought_episode_ids = @brought_ai.reorder(nil).distinct.pluck("appearances.episode_id")

    # ---------- Adjusted presence (continuous series collapse to 1) ----------
    # Build stable keys: ep-<episode_id> for normal, series-<series_id> for continuous
    # Use to_a to guarantee an array even if relation is empty
    @given_keys = @given_ai.to_a.map do |ai|
      ep  = ai.appearance.episode
      ser = ep.season&.series
      cont = !!(ep.season&.continuous_story || ser&.continuous_story)
      cont ? "series-#{ser&.id}" : "ep-#{ep.id}"
    end.uniq

    @brought_keys = @brought_ai.to_a.map do |ai|
      ep  = ai.appearance.episode
      ser = ep.season&.series
      cont = !!(ep.season&.continuous_story || ser&.continuous_story)
      cont ? "series-#{ser&.id}" : "ep-#{ep.id}"
    end.uniq

    # ---------- By country (adjusted totals) ----------
    @by_country = @item.appearance_items
                      .joins(appearance: { episode: [:location, { season: :series }] })
                      .select("locations.country AS country, #{adjusted_total_sql}")
                      .group("locations.country")
                      .order("total DESC")
  end
end
