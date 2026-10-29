class SurvivorsController < ApplicationController

  before_action :set_survivor, only: %i[show]

  def index
    @q    = params[:q].to_s.strip.first(100)
    @like = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
    @sort = params[:sort].to_s.presence_in(%w[challenges episodes name popular newest oldest recent]) || "challenges"

    # Short-circuit: if the search matches no survivor, skip the heavy
    # GROUP BY/aggregation entirely. Cache the exists-check briefly so
    # repeat bot crawls hitting the same garbage query don't re-run it.
    if @q.present?
      # Hashed: the raw string went straight into the cache key, so a crawler
      # could mint unbounded keys of any length.
      has_match = Rails.cache.fetch("survivors_search_hit/#{Digest::SHA256.hexdigest(@q.downcase)[0, 32]}", expires_in: 30.minutes) do
        Survivor.where("full_name ILIKE ?", @like).exists?
      end
      unless has_match
        @survivors = []
        @view_counts = {} if @sort == "popular"
        render :index and return
      end
    end

    base =
      Survivor
        .left_joins(appearances: { episode: { season: :series } })
        .joins(appearance_exits_join)
        .with_attached_avatar
        .where("survivors.full_name ILIKE ?", @like)
        .select([
          "survivors.*",
          episodes_total_capped_sql("episodes_total_count"),
          collapsed_episodes_sql("episodes_collapsed_count"),
          "COUNT(appearances.id) AS appearances_count",
          "MIN(episodes.air_date) AS debut_air_date",
          "MAX(episodes.air_date) AS latest_air_date"
        ].join(", "))
        .group("survivors.id")

    case @sort
    when "episodes"
      @survivors = base.order("episodes_total_count DESC, episodes_collapsed_count DESC, survivors.full_name ASC").to_a
    when "name"
      @survivors = base.order("survivors.full_name ASC").to_a
    when "newest"
      @survivors = base.order(Arel.sql("MIN(episodes.air_date) DESC NULLS LAST, survivors.full_name ASC")).to_a
    when "oldest"
      @survivors = base.order(Arel.sql("MIN(episodes.air_date) ASC NULLS LAST, survivors.full_name ASC")).to_a
    when "recent"
      @survivors = base.order(Arel.sql("MAX(episodes.air_date) DESC NULLS LAST, survivors.full_name ASC")).to_a
    when "popular"
      @survivors = base.order("survivors.full_name ASC").to_a
      # A scan of every survivor page view ever recorded, on each request for
      # the "popular" sort. Ten minutes stale is invisible for a ranking.
      view_counts_by_path = Rails.cache.fetch("survivors/popular_view_counts/v1", expires_in: 10.minutes) do
        PageView.where("path LIKE '/survivors/%'").group(:path).count
      end
      @view_counts = @survivors.each_with_object({}) do |s, h|
        h[s.id] = view_counts_by_path["/survivors/#{s.slug}"].to_i if s.slug.present?
      end
      @survivors = @survivors.sort_by { |s| [-(@view_counts[s.id] || 0), s.full_name.to_s] }
    else  # "challenges" — default
      @survivors = base.order("episodes_collapsed_count DESC, episodes_total_count DESC, survivors.full_name ASC").to_a
    end

    # Top-6 callout uses the same shape as before so the JSON-LD helper still works.
    @top_survivors = @survivors.first(6) if @survivors.respond_to?(:first)
  end

  def show
    #@survivor = Survivor.find(params[:id])

    # Reached through a slug the survivor used to have (they were renamed)?
    # Send the visitor, and search engines, to the current URL. Numeric ids are
    # left alone: they are a supported way in and not a stale slug.
    if params[:id].to_s !~ /\A\d+\z/ && params[:id].to_s != @survivor.slug
      redirect_to survivor_path(@survivor), status: :moved_permanently
      return
    end

    @appearances = @survivor.appearances
                            .includes(episode: [{ season: :series }, :location], appearance_items: :item)
                            .order("episodes.air_date NULLS LAST, episodes.id")

    base = @survivor.appearances.joins(episode: { season: :series })

    # DISTINCT episodes total, clamped at the tap-out air date on
    # continuous-story seasons (see ApplicationController#appearance_exits_join).
    row = base.except(:select).joins(appearance_exits_join).select(
      episodes_total_capped_sql("total")
    ).take
    @episodes_total_count = row["total"].to_i

    # Collapsed: 1 per continuous series, else distinct episodes
    row2 = base.except(:select).select(collapsed_episodes_sql("collapsed")).take
    @episodes_collapsed_count = row2["collapsed"].to_i

    @brought_counts = @survivor.appearance_items.where(source: :brought).joins(:item).group("items.id", "items.name").count
    @given_counts   = @survivor.appearance_items.where(source: :given).joins(:item).group("items.id", "items.name").count

    # Shop cards for what this survivor brought themselves (not what production gave them).
    brought_items = Item.where(id: @brought_counts.keys.map(&:first))
    # Only products documented for this survivor; gear tied to other survivors stays off their page.
    @shop_shelf = ShopShelf.build(holders: brought_items.index_with { [@survivor.full_name] }, only_named: true)
    @shop_links = ShopLinks.build(@shop_shelf.products)

    # Precomputed for the view: use @appearances in-memory instead of firing
    # 2-3 more small aggregate queries when the same data is already loaded.
    @episode_ids_count = @appearances.map(&:episode_id).uniq.size
    @country_counts    = @appearances
                          .map { |a| a.episode&.location&.country }
                          .compact_blank
                          .tally

    # Related survivors: co-stars ranked by number of shared episodes. Powers
    # the internal-linking "Related survivors" section — key for crawlability
    # so long-tail survivor pages sit in a dense link graph.
    co_counts = Appearance.where(episode_id: @survivor.appearances.select(:episode_id))
                          .where.not(survivor_id: @survivor.id)
                          .group(:survivor_id)
                          .order(Arel.sql("COUNT(*) DESC"))
                          .limit(6)
                          .count
    @related_survivors = Survivor.where(id: co_counts.keys)
                                 .with_attached_avatar
                                 .index_by(&:id)
                                 .values_at(*co_counts.keys)
                                 .compact
    @related_survivor_shared_counts = co_counts
  end

  private

  def set_survivor
    @survivor = Survivor.friendly.find(params[:id])  # This handles both slugs and IDs as fallback
  end
  
end
