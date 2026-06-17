class SurvivorsController < ApplicationController

  before_action :set_survivor, only: %i[show edit update destroy]

  def update
  end

  def edit
  end

  def destroy
  end 

  def index
    @q    = params[:q].to_s.strip
    @sort = params[:sort].to_s.presence_in(%w[challenges episodes name popular newest oldest]) || "challenges"

    base =
      Survivor
        .left_joins(appearances: { episode: { season: :series } })
        .joins(appearance_exits_join)
        .with_attached_avatar
        .where("survivors.full_name ILIKE ?", "%#{@q}%")
        .select([
          "survivors.*",
          episodes_total_capped_sql("episodes_total_count"),
          collapsed_episodes_sql("episodes_collapsed_count"),
          "COUNT(appearances.id) AS appearances_count",
          "MIN(episodes.air_date) AS debut_air_date"
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
    when "popular"
      @survivors = base.order("survivors.full_name ASC").to_a
      view_counts_by_path = PageView.where("path LIKE '/survivors/%'").group(:path).count
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
  end

  private

  def serialize_row(s)
    h = view_context
    links = []
    links << h.link_to("IG",   s.instagram, target: "_blank", rel: "noopener") if s.instagram.present?
    links << h.link_to("FB",   s.facebook,  target: "_blank", rel: "noopener") if s.facebook.present?
    links << h.link_to("YT",   s.youtube,   target: "_blank", rel: "noopener") if s.youtube.present?
    links << h.link_to("Site", s.website,   target: "_blank", rel: "noopener") if s.website.present?
    links << h.link_to("Merch", s.merch,    target: "_blank", rel: "noopener") if s.merch.present?

    episodes_total     = s.respond_to?(:episodes_total_count)     ? s.episodes_total_count     : s.appearances.distinct.count(:episode_id)
    episodes_collapsed = s.respond_to?(:episodes_collapsed_count) ? s.episodes_collapsed_count : episodes_total

    [
      h.link_to(s.full_name, h.survivor_path(s)),
      episodes_collapsed, # show collapsed stat
      (links.any? ? h.safe_join(links, " · ".html_safe) : h.content_tag(:span, "-", class: "text-gray-400"))
    ]
  end

  def set_survivor
    @survivor = Survivor.friendly.find(params[:id])  # This handles both slugs and IDs as fallback
  end
  
end
