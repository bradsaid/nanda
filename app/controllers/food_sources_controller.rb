class FoodSourcesController < ApplicationController
  include SlugRedirects

  def index
    @category = params[:category].to_s.strip.presence

    scope = FoodSource.all
    scope = scope.where(category: @category) if @category.present?

    @food_counts = scope
      .group(:name, :category)
      .order(Arel.sql("COUNT(DISTINCT episode_id) DESC"))
      .count("DISTINCT episode_id")

    # { ["squirrel", "animal"] => 3, ["oranges", "plant"] => 1, ... }
  end

  def show
    # /food_sources/angel-fish; the old /food_sources/angel%20fish (any case) 301s to it.
    match = resolve_name_slug!(:food_source, params[:name]) { |slug| food_source_path(name: slug) } or return
    @name = match.key
    @food_sources = FoodSource
      .where(name: @name)
      .includes(episode: [:location, { season: :series }])
      .order("episodes.air_date DESC NULLS LAST")
    @episode_count = @food_sources.distinct.count(:episode_id)
    # Linked to fewer episodes than ThinContent.food_source_min_episodes: noindex, follow, and
    # not in the sitemap (SitemapUrls applies the same rule).
    set_robots("noindex, follow") if ThinContent.thin_food_source?(@episode_count)
  end
end
