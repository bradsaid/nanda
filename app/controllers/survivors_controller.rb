class SurvivorsController < ApplicationController

  before_action :set_survivor, only: %i[show edit update destroy]

  def update
  end

  def edit
  end

  def destroy
  end 

  def index
    @q = params[:q].to_s.strip

    @survivors =
      Survivor
        .left_joins(appearances: { episode: { season: :series } })
        .where("survivors.full_name ILIKE ?", "%#{@q}%")
        .select([
          "survivors.*",
          "COUNT(DISTINCT episodes.id) AS episodes_total_count",
          collapsed_episodes_sql("episodes_collapsed_count"),
          "COUNT(appearances.id) AS appearances_count"
        ].join(", "))
        .group("survivors.id")
        .order("survivors.full_name ASC")
        .limit(1000)

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

  def show
    #@survivor = Survivor.find(params[:id])

    @appearances = @survivor.appearances
                            .includes(episode: [:season, :location], appearance_items: :item)
                            .order("episodes.air_date NULLS LAST, episodes.id")

    base = @survivor.appearances.joins(episode: { season: :series })

    # DISTINCT episodes total
    row = base.except(:select).select("COUNT(DISTINCT episodes.id) AS total").take
    @episodes_total_count = row["total"].to_i

    # Collapsed: 1 per continuous series, else distinct episodes
    row2 = base.except(:select).select(collapsed_episodes_sql("collapsed")).take
    @episodes_collapsed_count = row2["collapsed"].to_i

    @brought_counts = @survivor.appearance_items.where(source: :brought).joins(:item).group("items.name").count
    @given_counts   = @survivor.appearance_items.where(source: :given).joins(:item).group("items.name").count
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
