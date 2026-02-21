class FoodSourcesController < ApplicationController
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
    @name = params[:name].to_s.strip.downcase
    @food_sources = FoodSource
      .where(name: @name)
      .includes(:survivor, episode: [:location, { season: :series }])
      .order("episodes.air_date DESC NULLS LAST")
    @episode_count = @food_sources.distinct.count(:episode_id)
  end
end
