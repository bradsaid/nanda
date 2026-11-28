# app/controllers/episodes_controller.rb
class EpisodesController < ApplicationController
  include GearShelf
  include Paginatable
  include SlugRedirects

  # The season overview is ~8 KB of markup per season (cast chips, three episode rows), so
  # eight seasons a page keeps /episodes near 100 KB instead of ~340 KB. The country
  # pages paginate their cards (one per episode, or per continuous-story season).
  SEASONS_PER_PAGE        = 8
  COUNTRY_BLOCKS_PER_PAGE = 12

  def index
    @country = params[:country].to_s.strip
    # /episodes?country=X has no layout of its own in index.html.slim (with
    # @location/@season nil it fell through to the season-overview layout with
    # empty @seasons: an empty "Jump to a season" select and no episodes at
    # all). The real country page is #by_country, so send old/hand-typed
    # ?country= URLs there permanently.
    # (An unknown country is the by_country 404, one redirect later.)
    if @country.present?
      @skip_page_view = true
      redirect_to by_country_episodes_path(country: NameSlugs.slug(:country, @country)), status: :moved_permanently
      return
    end

    if params[:location_id].present?
      @location = Location.find_by(id: params[:location_id].to_i)
      return render status: :not_found, plain: "Location not found" unless @location

      @episodes = Episode.where(location_id: @location.id)
                         .includes(:location, season: :series, appearances: [{ survivor: { avatar_attachment: :blob } }, { appearance_items: :item }])
                         .order(Arel.sql("air_date IS NULL, air_date DESC, number_in_season ASC"))
      @seasons = []; @episodes_by_season = {}; @episode_counts = {}
      build_gear_shelf(label: "Seen at this location", episodes: @episodes.to_a) { |scope| scope.where(episodes: { location_id: @location.id }) }

    elsif params[:season_id].present? || (params[:series_id].present? && params[:season].present?)
      @season =
        if params[:season_id].present?
          Season.find_by(id: params[:season_id].to_i)
        else
          Season.find_by(series_id: params[:series_id].to_i, number: params[:season].to_i)
        end
      return render status: :not_found, plain: "Season not found" unless @season

      @episodes = Episode.where(season_id: @season.id)
                         .includes(:location, season: :series, appearances: [{ survivor: { avatar_attachment: :blob } }, { appearance_items: :item }])
                         .order("number_in_season ASC")
      @seasons = []; @episodes_by_season = {}; @episode_counts = {}
      build_gear_shelf(label: "Seen this season", episodes: @episodes.to_a) { |scope| scope.where(episodes: { season_id: @season.id }) }

    else
      @sort = params[:sort].to_s
      page  = requested_page or return

      # Subquery for earliest valid airdate
      sub = Episode
              .where.not(air_date: nil)
              .select("season_id, MIN(air_date) AS first_air_date, MAX(air_date) AS last_air_date")
              .group("season_id")
      with_dates = "LEFT JOIN (#{sub.to_sql}) epdates ON epdates.season_id = seasons.id"
      dated_cols = "seasons.*, epdates.first_air_date, epdates.last_air_date, series.name AS series_name"

      # `ordered` fixes the order of ALL seasons (every order ends in seasons.id, so page
      # boundaries are stable); the page is a limit/offset slice of it.
      ordered, columns =
        case @sort
        when "airdate" # oldest first
          [Season.joins(:series).joins(with_dates)
                 .order(Arel.sql("COALESCE(epdates.first_air_date, DATE '9999-12-31') ASC, series.name ASC, seasons.number ASC, seasons.id ASC")),
           dated_cols]
        when "newest" # newest first
          [Season.joins(:series).joins(with_dates)
                 .order(Arel.sql("COALESCE(epdates.last_air_date, DATE '1900-01-01') DESC, series.name ASC, seasons.number ASC, seasons.id ASC")),
           dated_cols]
        else
          [Season.joins(:series).order(Arel.sql("seasons.series_id ASC, seasons.number ASC, seasons.id ASC")), nil]
        end

      # (id, series name, number) of every season in order: feeds the "Jump to a season"
      # menu, whose entries for seasons on other pages link to the page they are on.
      all_seasons = ordered.pluck("seasons.id", "series.name", "seasons.number")
      ensure_page_in_range!(page, total_pages_for(all_seasons.size, SEASONS_PER_PAGE))
      limit, offset = page_window(page, SEASONS_PER_PAGE)

      page_scope = ordered.includes(:series).limit(limit).offset(offset)
      page_scope = page_scope.select(columns) if columns
      @seasons = page_scope.to_a
      @seasons_page = Kaminari.paginate_array(@seasons, total_count: all_seasons.size).page(page).per(SEASONS_PER_PAGE)
      @season_jump = all_seasons.each_with_index.map do |(id, series_name, number), i|
        { id: id, label: "#{series_name} • S#{number}", page: i / SEASONS_PER_PAGE + 1 }
      end

      season_ids = @seasons.map(&:id)

      # One batched load of every episode for the visible seasons, ordered so
      # the first 3 per season are the ones we want to preview. Preload the
      # `survivors` through-association directly (not via :appearances) so
      # the view's per-episode `ep.survivors` chip render doesn't N+1.
      # `season: :series` is here for the JSON-LD helper which reads them.
      @all_episodes_by_season = Episode
        .where(season_id: season_ids)
        .includes(:location, season: :series, survivors: { avatar_attachment: :blob })
        .order(Arel.sql("number_in_season ASC NULLS LAST, id ASC"))
        .group_by(&:season_id)

      @episodes_by_season = @seasons.index_with { |s| (@all_episodes_by_season[s.id] || []).first(3) }
      @episode_counts     = @all_episodes_by_season.transform_values(&:size)

      @survivor_counts_by_season = Appearance.joins(:episode)
                                              .where(episodes: { season_id: season_ids })
                                              .distinct
                                              .group("episodes.season_id")
                                              .count(:survivor_id)

      # @episodes was previously loaded here with a huge eager query, but the
      # season-grid view + JSON-LD helper both read from @episodes_by_season
      # in the no-filter branch. Skip it.
      @episodes = []

      # For continuous-story seasons we want to render a single "Cast" row
      # at the top of the season card instead of repeating the same chips on
      # every episode row. Pre-compute the unique survivor list per such
      # season — one query for the (season_id, survivor_id) pairs, one for
      # the survivors+avatars themselves.
      continuous_season_ids = @seasons.select { |s| s.respond_to?(:continuous_story_effective?) && s.continuous_story_effective? }.map(&:id)
      if continuous_season_ids.any?
        pairs = Appearance.joins(:episode)
                          .where(episodes: { season_id: continuous_season_ids })
                          .distinct
                          .pluck(Arel.sql("episodes.season_id"), Arel.sql("appearances.survivor_id"))
        survivors_by_id = Survivor.where(id: pairs.map(&:last).uniq).with_attached_avatar.index_by(&:id)
        @season_cast_by_id = pairs.group_by(&:first).transform_values { |arr|
          arr.map { |_, sid| survivors_by_id[sid] }.compact.sort_by { |s| s.full_name.to_s.downcase }
        }
      else
        @season_cast_by_id = {}
      end
    end
  end

  def show
    # By slug, by an old slug (history) or by numeric id; the last two 301 to the slug URL.
    @episode = find_by_slug_or_id(
      Episode.includes(:location, :episode_shelters, :medical_calls, :bushcraft_items, season: :series,
                       episode_traps: :food_sources,
                       appearances: [{ survivor: { avatar_attachment: :blob } }, { appearance_items: :item }],
                       food_sources: :episode_trap),
      params[:id]
    )
    return if redirect_to_current_slug(@episode)

    # No synopsis = thin page: `noindex, follow` (meta + X-Robots-Tag) and out of the sitemap,
    # while ThinContent.noindex_episodes_without_synopsis? (NOINDEX_THIN_EPISODES) is on.
    set_robots("noindex, follow") if @episode.thin?

    # On continuous-story seasons (XL, Global Showdown, Alone, etc.) the
    # "Copy participants from previous episode" admin button carries every
    # survivor forward to every later episode by default — so the raw
    # appearance list for, say, GS S1 E5 includes survivors who tapped /
    # were eliminated in an earlier episode. Drop any appearance whose
    # survivor has a result recorded on an *earlier* episode this season;
    # the result-bearing episode itself stays visible.
    season = @episode.season
    is_continuous = season && (season.continuous_story || season.series&.continuous_story)
    if is_continuous && @episode.air_date
      exit_air_dates =
        Appearance
          .joins(:episode)
          .where("episodes.season_id = ?", @episode.season_id)
          .where(survivor_id: @episode.appearances.map(&:survivor_id))
          .where.not(result: nil)
          .group(:survivor_id)
          .minimum("episodes.air_date")
      @active_appearances = @episode.appearances.reject do |a|
        d = exit_air_dates[a.survivor_id]
        d && d < @episode.air_date
      end
    else
      @active_appearances = @episode.appearances
    end

    # Shop cards for the gear in this episode (brought or given).
    holders = Hash.new { |h, k| h[k] = [] }
    @active_appearances.each do |a|
      a.appearance_items.each do |ai|
        holders[ai.item] << a.survivor.full_name if %w[brought given].include?(ai.source)
      end
    end
    @shop_shelf = ShopShelf.build(holders: holders.transform_values(&:uniq), episode: @episode)
    @shop_links = ShopLinks.build(@shop_shelf.products)

    # Related episodes: prefer other episodes in the same season, then fall
    # back to episodes from the same country. Powers the on-page "Related
    # episodes" internal-linking module.
    same_season = Episode.includes(:location, season: :series)
                         .where(season_id: @episode.season_id)
                         .where.not(id: @episode.id)
                         .order(Arel.sql("air_date IS NULL, air_date"))
                         .limit(6)
                         .to_a

    if same_season.size < 6 && @episode.location&.country.present?
      needed = 6 - same_season.size
      country_eps = Episode.includes(:location, season: :series)
                           .joins(:location)
                           .where("TRIM(LOWER(locations.country)) = ?", @episode.location.country.downcase)
                           .where.not(id: [@episode.id, *same_season.map(&:id)])
                           .order(Arel.sql("air_date IS NULL, air_date DESC"))
                           .limit(needed)
                           .to_a
      @related_episodes = same_season + country_eps
    else
      @related_episodes = same_season
    end
  end

  def by_country
    # /episodes/by_country/south-africa. The old /episodes/by_country/South%20Africa (any
    # case, %20 or +) 301s to the slug; a name that matches no country is a 404.
    match = resolve_name_slug!(:country, params[:country]) { |slug| by_country_episodes_path(country: slug) } or return
    @country = match.name
    @country_slug = match.slug
    page = requested_page or return
    @episodes =
      Episode
        .includes(:location, season: :series, appearances: { survivor: { avatar_attachment: :blob } })
        .joins(:location)
        .where("TRIM(LOWER(locations.country)) = ?", match.key)
        .order(Arel.sql("air_date IS NULL, air_date DESC"))

    # Cards, newest first: a continuous-story season with 2+ episodes here is ONE card with
    # shared cast, any other episode is its own card. The cards are what get paginated.
    blocks = country_blocks(@episodes.to_a)
    ensure_page_in_range!(page, total_pages_for(blocks.size, COUNTRY_BLOCKS_PER_PAGE))
    limit, offset = page_window(page, COUNTRY_BLOCKS_PER_PAGE)
    @blocks = Kaminari.paginate_array(blocks.slice(offset, limit).to_a, total_count: blocks.size).page(page).per(COUNTRY_BLOCKS_PER_PAGE)

    # Shop cards for gear brought or given in this country, busiest items first.
    # (Built for the whole country; only page 1 shows it.)
    build_gear_shelf(label: "Seen in #{@country}", episodes: @episodes.to_a) do |scope|
      scope.where("TRIM(LOWER(locations.country)) = ?", match.key)
    end
  end

  private

  def country_blocks(episodes)
    blocks = []
    episodes.group_by(&:season).each do |season, eps|
      if season&.continuous_story_effective? && eps.size >= 2
        sorted = eps.sort_by { |ep| [ep.air_date || Date.new(1, 1, 1), ep.id] }
        blocks << { kind: :season, season: season, eps: sorted, id: sorted.first.id,
                    sort_date: (eps.map(&:air_date).compact.max || Date.new(1, 1, 1)) }
      else
        eps.each { |ep| blocks << { kind: :ep, ep: ep, id: ep.id, sort_date: (ep.air_date || Date.new(1, 1, 1)) } }
      end
    end
    # id breaks date ties, so card order (and therefore the page boundaries) is stable.
    blocks.sort_by { |b| [-b[:sort_date].to_time.to_i, b[:id]] }
  end
end
