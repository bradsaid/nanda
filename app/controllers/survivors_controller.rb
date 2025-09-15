class SurvivorsController < ApplicationController

  def index
    @q = params[:q].to_s.strip

    # Precompute episode counts to avoid N+1
    @survivors =
      Survivor.left_joins(:appearances)
              .where("survivors.full_name ILIKE ?", "%#{@q}%") # drop if no search
              .select("survivors.*, COUNT(appearances.id) AS appearances_count")
              .group("survivors.id")
              .order("survivors.full_name ASC")
              .limit(1000)
  end

  def show
    @survivor = Survivor.find(params[:id])

    # Eager-load to avoid N+1
    @appearances = @survivor.appearances
                            .includes(:episode => [:season, :location], :appearance_items => :item)
                            .order("episodes.air_date NULLS LAST, episodes.id")

    # Rollups
    @brought_counts = @survivor.appearance_items
                               .where(source: :brought).joins(:item)
                               .group("items.name").count
    @given_counts = @survivor.appearance_items
                             .where(source: :given).joins(:item)
                             .group("items.name").count
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

    [
      h.link_to(s.full_name, h.survivor_path(s)),
      (s.respond_to?(:episodes_count) ? s.episodes_count : s.appearances.size),
      (links.any? ? h.safe_join(links, " · ".html_safe) : h.content_tag(:span, "-", class: "text-gray-400"))
    ]
  end
  
end
