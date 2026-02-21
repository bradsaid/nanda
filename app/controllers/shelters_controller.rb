class SheltersController < ApplicationController
  def index
    @shelter_counts = EpisodeShelter
      .group(:shelter_type)
      .order(Arel.sql("COUNT(DISTINCT episode_id) DESC"))
      .count("DISTINCT episode_id")
  end

  def show
    @shelter_type = params[:shelter_type].to_s.strip
    @shelters = EpisodeShelter
      .where(shelter_type: @shelter_type)
      .includes(episode: [:location, { season: :series }])
      .order("episodes.air_date DESC NULLS LAST")
    @episode_count = @shelters.distinct.count(:episode_id)
  end
end
