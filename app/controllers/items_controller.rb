class ItemsController < ApplicationController
  def index
    @q       = params[:q].to_s.strip
    @country = params[:country].presence
    @limit   = (params[:limit].presence || 20).to_i.clamp(1, 200)

    # For filter dropdown
    @countries = Location.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)

    # Base join across the facts we need
    ai = AppearanceItem.joins(:item, appearance: { episode: :location })

    ai = ai.where("items.name ILIKE ?", "%#{@q}%") if @q.present?
    ai = ai.where(locations: { country: @country }) if @country.present?

    # Top brought / given
    @top_brought = ai.where(source: "brought")
                     .select("items.id, items.name, SUM(appearance_items.quantity) AS total")
                     .group("items.id, items.name")
                     .order("total DESC").limit(@limit)

    @top_given   = ai.where(source: "given")
                     .select("items.id, items.name, SUM(appearance_items.quantity) AS total")
                     .group("items.id, items.name")
                     .order("total DESC").limit(@limit)

    # Rarest (by total occurrences > 0)
    @rarest = ai.select(<<~SQL.squish)
                items.id, items.name,
                SUM(appearance_items.quantity) AS total,
                SUM(CASE WHEN appearance_items.source='brought' THEN appearance_items.quantity ELSE 0 END) AS brought_total,
                SUM(CASE WHEN appearance_items.source='given'   THEN appearance_items.quantity ELSE 0 END) AS given_total
              SQL
              .group("items.id, items.name")
              .having("SUM(appearance_items.quantity) > 0")
              .order("total ASC, items.name ASC")
              .limit(@limit)

    # Items per country (top N per country)
    rows = ai.select("locations.country AS country, items.id AS item_id, items.name AS item_name, SUM(appearance_items.quantity) AS total")
             .group("locations.country, items.id, items.name")
             .order("locations.country ASC, total DESC")

    @items_by_country = rows.group_by { |r| r.country }.transform_values { |arr| arr.first(10) }
  end

  def show
    @item    = Item.find(params[:id])
    @country = params[:country].presence

    scope = @item.appearance_items
                 .joins(appearance: [{ episode: [:season, :location] }, :survivor])
                 .includes(appearance: [:survivor, episode: [:season, :location]])

    scope = scope.where(locations: { country: @country }) if @country.present?

    @brought_ai = scope.where(source: "brought").order("episodes.air_date NULLS LAST, survivors.full_name")
    @given_ai   = scope.where(source: "given").order("episodes.air_date NULLS LAST, survivors.full_name")

    # Top countries for this item
    @by_country = @item.appearance_items
                       .joins(appearance: { episode: :location })
                       .group("locations.country")
                       .select("locations.country AS country, SUM(appearance_items.quantity) AS total")
                       .order("total DESC")
  end
end
