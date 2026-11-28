class SheltersController < ApplicationController
  include SlugRedirects

  def index
    @shelter_counts = EpisodeShelter
      .group(:shelter_type)
      .order(Arel.sql("COUNT(DISTINCT episode_id) DESC"))
      .count("DISTINCT episode_id")
  end

  def show
    # /shelters/lean-to; the old /shelters/Lean-to (the type spelled out) 301s to the slug.
    match = resolve_name_slug!(:shelter, params[:shelter_type]) { |slug| shelter_path(shelter_type: slug) } or return
    @shelter_type = match.key
    @shelters = EpisodeShelter
      .where(shelter_type: @shelter_type)
      .includes(episode: [:location, { season: :series }])
      .order("episodes.air_date DESC NULLS LAST")
    @episode_count = @shelters.distinct.count(:episode_id)
    # Same thin-page rule as food sources (ThinContent.shelter_min_episodes).
    set_robots("noindex, follow") if ThinContent.thin_shelter?(@episode_count)
  end
end
