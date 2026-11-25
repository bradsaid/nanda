class SurvivorsController < ApplicationController
  include Paginatable

  # Cards per page: ~48 keeps /survivors around 45 KB of HTML instead of ~370 KB.
  PER_PAGE = 48

  before_action :set_survivor, only: %i[show]

  def index
    @q    = params[:q].to_s.strip.first(100)
    @like = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
    @sort = params[:sort].to_s.presence_in(%w[challenges episodes name popular newest oldest recent]) || "challenges"
    page  = requested_page or return

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
        ensure_page_in_range!(page, 1)
        @survivors = paginated_survivors([], 0, page)
        @view_counts = {} if @sort == "popular"
        render :index and return
      end
    end

    matching = Survivor.where("survivors.full_name ILIKE ?", @like)
    total    = matching.count
    ensure_page_in_range!(page, total_pages_for(total, PER_PAGE))
    limit, offset = page_window(page, PER_PAGE)

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

    # Every order ends in survivors.id so the page boundaries are stable between requests.
    ordered = lambda do |sql|
      base.order(Arel.sql("#{sql}, survivors.id ASC")).limit(limit).offset(offset).to_a
    end

    rows =
      case @sort
      when "episodes"
        ordered.("episodes_total_count DESC, episodes_collapsed_count DESC, survivors.full_name ASC")
      when "name"
        ordered.("survivors.full_name ASC")
      when "newest"
        ordered.("MIN(episodes.air_date) DESC NULLS LAST, survivors.full_name ASC")
      when "oldest"
        ordered.("MIN(episodes.air_date) ASC NULLS LAST, survivors.full_name ASC")
      when "recent"
        ordered.("MAX(episodes.air_date) DESC NULLS LAST, survivors.full_name ASC")
      when "popular"
        popular_page(base, matching, limit, offset)
      else  # "challenges" - default
        ordered.("episodes_collapsed_count DESC, episodes_total_count DESC, survivors.full_name ASC")
      end

    @survivors = paginated_survivors(rows, total, page)
    @az_pages = az_pages_for(matching) if @sort == "name"

    # Top-6 callout uses the same shape as before so the JSON-LD helper still works.
    @top_survivors = @survivors.first(6)
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

    build_explore_links(exclude_ids: co_counts.keys)
  end

  private

  # Wraps one page of rows so the view can `paginate` it (and still use it as a plain array).
  def paginated_survivors(rows, total, page)
    Kaminari.paginate_array(rows, total_count: total).page(page).per(PER_PAGE)
  end

  # "Popular" ranks by page views, which live in the page_views table keyed by path and
  # not in this query, so the ranking is done in Ruby on a light (id, slug, name) list of
  # every matching survivor; only the requested page of ids goes through the heavy
  # aggregate query, and its rows are put back in ranked order.
  def popular_page(base, matching, limit, offset)
    # A scan of every survivor page view ever recorded, on each request for
    # the "popular" sort. Ten minutes stale is invisible for a ranking.
    view_counts_by_path = Rails.cache.fetch("survivors/popular_view_counts/v1", expires_in: 10.minutes) do
      PageView.where("path LIKE '/survivors/%'").group(:path).count
    end
    people = matching.pluck(:id, :slug, :full_name)
    @view_counts = people.each_with_object({}) do |(id, slug, _), h|
      h[id] = view_counts_by_path["/survivors/#{slug}"].to_i if slug.present?
    end
    ranked   = people.sort_by { |id, _, name| [-(@view_counts[id] || 0), name.to_s, id] }
    page_ids = ranked.slice(offset, limit).to_a.map(&:first)
    by_id    = base.where(survivors: { id: page_ids }).index_by(&:id)
    page_ids.filter_map { |id| by_id[id] }
  end

  # For the phone A-Z strip on the name sort: first page each initial appears on, over the
  # whole (searched) list, so a letter link can lead to another page.
  def az_pages_for(matching)
    names = matching.order(Arel.sql("survivors.full_name ASC, survivors.id ASC")).pluck(:full_name)
    names.each_with_index.each_with_object({}) do |(name, i), h|
      letter = name.to_s.strip[0].to_s.upcase
      letter = "#" unless letter.match?(/[A-Z]/)
      h[letter] ||= i / PER_PAGE + 1
    end
  end

  # More internal links for the survivor page: other survivalists from the
  # seasons this person was on, and from the countries they filmed in. Only ids
  # are cached (an hour is plenty for a link list); records are loaded fresh.
  EXPLORE_SEASONS     = 3
  EXPLORE_COUNTRIES   = 2
  EXPLORE_PER_SEASON  = 12
  EXPLORE_PER_COUNTRY = 10

  def build_explore_links(exclude_ids:)
    plan = Rails.cache.fetch("survivors/#{@survivor.id}/explore_links/v1", expires_in: 1.hour) do
      skip = [@survivor.id, *exclude_ids]
      shown = skip.dup

      season_ids = @appearances.map { |a| a.episode&.season_id }.compact.uniq.last(EXPLORE_SEASONS).reverse
      seasons = season_ids.filter_map do |sid|
        scope = Appearance.joins(:episode).where(episodes: { season_id: sid }).where.not(survivor_id: skip)
        total = scope.distinct.count(:survivor_id)
        next if total.zero?
        ids = Survivor.where(id: scope.select(:survivor_id)).where.not(id: shown)
                      .order(:full_name).limit(EXPLORE_PER_SEASON).pluck(:id)
        shown.concat(ids)
        { season_id: sid, ids: ids, total: total } if ids.any?
      end

      countries = @country_counts.sort_by { |name, n| [-n, name] }.first(EXPLORE_COUNTRIES).filter_map do |name, _|
        ranked = Appearance.joins(episode: :location)
                           .where("TRIM(LOWER(locations.country)) = ?", name.to_s.strip.downcase)
                           .where.not(survivor_id: shown)
                           .group(:survivor_id)
                           .order(Arel.sql("COUNT(*) DESC"), :survivor_id)
                           .limit(EXPLORE_PER_COUNTRY).count.keys
        shown.concat(ranked)
        { country: name, ids: ranked } if ranked.any?
      end

      { seasons: seasons, countries: countries }
    end

    all_ids = (plan[:seasons] + plan[:countries]).flat_map { |h| h[:ids] }
    people  = Survivor.where(id: all_ids).select(:id, :full_name, :slug).index_by(&:id)
    seasons = Season.where(id: plan[:seasons].map { |h| h[:season_id] }).includes(:series).index_by(&:id)

    @explore_seasons = plan[:seasons].filter_map do |h|
      season = seasons[h[:season_id]]
      list   = people.values_at(*h[:ids]).compact
      { season: season, survivors: list, total: h[:total] } if season && list.any?
    end
    @explore_countries = plan[:countries].filter_map do |h|
      list = people.values_at(*h[:ids]).compact
      { country: h[:country], survivors: list } if list.any?
    end
  end

  def set_survivor
    @survivor = Survivor.friendly.find(params[:id])  # This handles both slugs and IDs as fallback
  end
  
end
