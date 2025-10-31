class ItemsController < ApplicationController
  def index
    @q       = params[:q].to_s.strip
    @country = params[:country].presence
    @limit   = (params[:limit].presence || 20).to_i.clamp(1, 200)

    @countries = Location.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)

    # Base (used for your other lists)
    ai = AppearanceItem.joins(:item, appearance: { episode: [:location, { season: :series }] })
    ai = ai.where("items.name ILIKE ?", "%#{@q}%") if @q.present?
    ai = ai.where(locations: { country: @country }) if @country.present?

    # ===== Top lists =====
    # Brought: count each survivor’s brought item; collapse across continuous series.
    # Given:   count once per episode (shared); collapse across continuous series.
    items_scope = Item.all
    items_scope = items_scope.where("items.name ILIKE ?", "%#{@q}%") if @q.present?

    brought_sub = brought_subquery(@country, @q)
    given_sub   = given_subquery(@country, @q)
=begin
    @top_brought = items_scope 
      .joins("JOIN (#{brought_sub.to_sql}) bi ON bi.item_id = items.id")
      .select("items.id, items.name, COUNT(*) AS total")
      .group("items.id, items.name")
      .order("total DESC")
      .limit(@limit)
=end

    @top_brought =
      AppearanceItem.where(source: "brought")
        .joins(:item)
        .group("items.id", "items.name")
        .select("items.id, items.name, SUM(appearance_items.quantity) AS total")
        .order("total DESC")
=begin
    @top_given = items_scope
      .joins("JOIN (#{given_sub.to_sql}) gi ON gi.item_id = items.id")
      .select("items.id, items.name, COUNT(*) AS total")
      .group("items.id, items.name")
      .order("total DESC")
      .limit(@limit)
=end

    @top_given =
      AppearanceItem.where(source: "given")
        .joins(:item)
        .group("items.id", "items.name")
        .select("items.id, items.name, SUM(appearance_items.quantity) AS total")
        .order("total DESC")


    # ===== Given in episodes (unique & adjusted) =====
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

    # ===== Rarest (existing logic preserved) =====
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

    # ===== Items per country (unique per episode) and adjusted =====
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

    @items_by_type =
      Item.where.not(item_type: [nil, ""])
          .group(:item_type)
          .order(Arel.sql("COUNT(*) DESC"))
          .count
          
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

  def type
    @item_type = params[:item_type].to_s
    @country   = params[:country].presence

    # ✅ Correct join syntax (array under :appearance)
    ai = AppearanceItem
          .joins(:item, appearance: [{ episode: [:location, { season: :series }] }, :survivor])
          .where(items: { item_type: @item_type })

    ai = ai.where(locations: { country: @country }) if @country

    @given_ai   = ai.where(source: "given").includes(appearance: [:episode, :survivor])
    @brought_ai = ai.where(source: "brought").includes(appearance: [:episode, :survivor])

    @given_episode_ids   = @given_ai.select("DISTINCT appearances.episode_id").pluck("appearances.episode_id")
    @brought_episode_ids = @brought_ai.select("DISTINCT appearances.episode_id").pluck("appearances.episode_id")

    @by_country = ai
      .select("locations.country AS country, COUNT(DISTINCT appearances.episode_id) AS total")
      .group("locations.country")
      .order("total DESC")

    @items_in_type_count = Item.where(item_type: @item_type).count
  end

  private

  # For brought items:
  # - Count per survivor (appearance) within each episode.
  # - Collapse across continuous story by counting once per series instead of per episode
  #   when seasons.continuous_story OR series.continuous_story.
  # Emits DISTINCT rows of (grp_key, item_id, appearance_id).
  def brought_subquery(country, q)
    key_sql = <<~SQL.squish
      CASE
        WHEN COALESCE(seasons.continuous_story, FALSE) OR COALESCE(series.continuous_story, FALSE)
          THEN series.id::text
        ELSE episodes.id::text
      END
    SQL

    rel = AppearanceItem
            .where(source: "brought")
            .joins(:item, appearance: { episode: [:location, { season: :series }] })

    rel = rel.where("items.name ILIKE ?", "%#{q}%") if q.present?
    rel = rel.where(locations: { country: country }) if country.present?

    rel.select("DISTINCT (#{key_sql}) AS grp_key, appearance_items.item_id, appearance_items.appearance_id")
  end

  # For given items:
  # - Shared, so count once per episode.
  # - Collapse across continuous story by counting once per series instead of per episode
  #   when seasons.continuous_story OR series.continuous_story.
  # Emits DISTINCT rows of (grp_key, item_id).
  def given_subquery(country, q)
    key_sql = <<~SQL.squish
      CASE
        WHEN COALESCE(seasons.continuous_story, FALSE) OR COALESCE(series.continuous_story, FALSE)
          THEN series.id::text
        ELSE episodes.id::text
      END
    SQL

    rel = AppearanceItem
            .where(source: "given")
            .joins(:item, appearance: { episode: [:location, { season: :series }] })

    rel = rel.where("items.name ILIKE ?", "%#{q}%") if q.present?
    rel = rel.where(locations: { country: country }) if country.present?

    rel.select("DISTINCT (#{key_sql}) AS grp_key, appearance_items.item_id")
  end
end
