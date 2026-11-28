module Admin
  # Focused workflow view for writing episode synopses. Defaults to
  # traffic-importance ordering so Brad always sees the most-viewed
  # still-missing episode at the top of the list.
  #
  # "Missing" uses Episode.without_synopsis, the same rule that decides which episode pages
  # are noindexed and left out of the sitemap (see ThinContent), so this queue is exactly the
  # list of pages that go live in search once a synopsis is written.
  class SynopsisQueueController < BaseController
    def index
      @sort = params[:sort].to_s.presence || "traffic"
      @only = params[:only].to_s.presence  # nil | "missing" | "done"

      # Traffic per episode over the last 30 days, keyed by episode id.
      # Shared cache with Admin::EpisodesController so we don't rescan
      # PageView twice per admin session.
      @traffic_by_episode_id = episode_traffic_by_id

      scope = Episode.includes(season: :series, location: {})
      scope = scope.without_synopsis if @only == "missing"
      scope = scope.with_synopsis    if @only == "done"

      case @sort
      when "chronological"
        @episodes = scope.joins(season: :series)
                          .order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC")
                          .to_a
      else  # "traffic" (default)
        # Load the entire filtered set once, sort in Ruby by traffic desc.
        all = scope.to_a
        @episodes = all.sort_by { |ep| [-(@traffic_by_episode_id[ep.id] || 0), ep.id] }
      end

      @total    = Episode.count
      @done     = Episode.with_synopsis.count
      @missing  = @total - @done
      # With ThinContent on, "missing" is exactly the set of episode pages served noindex.
      @noindexed = ThinContent.noindex_episodes_without_synopsis? ? @missing : 0
      @progress = @total.zero? ? 0 : (100.0 * @done / @total).round(1)
    end
  end
end
