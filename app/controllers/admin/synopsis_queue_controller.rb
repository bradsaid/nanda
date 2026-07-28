module Admin
  # Focused workflow view for writing episode synopses. Defaults to
  # traffic-importance ordering so Brad always sees the most-viewed
  # still-missing episode at the top of the list.
  class SynopsisQueueController < BaseController
    def index
      @sort = params[:sort].to_s.presence || "traffic"
      @only = params[:only].to_s.presence  # nil | "missing" | "done"

      # Traffic per episode over the last 30 days, keyed by episode id.
      # Shared cache with Admin::EpisodesController so we don't rescan
      # PageView twice per admin session.
      path_counts = Rails.cache.fetch("admin/episodes/traffic_counts/v1", expires_in: 5.minutes) do
        PageView.where(created_at: 30.days.ago..)
                .where("path ~ ?", '^/episodes/[0-9]+$')
                .group(:path).count
      end
      @traffic_by_episode_id = path_counts.each_with_object({}) do |(path, count), h|
        id = path.split("/").last.to_i
        h[id] = count if id.positive?
      end

      scope = Episode.includes(season: :series, location: {})
      scope = scope.where(synopsis: [nil, ""])       if @only == "missing"
      scope = scope.where.not(synopsis: [nil, ""])   if @only == "done"

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
      @done     = Episode.where.not(synopsis: [nil, ""]).count
      @missing  = @total - @done
      @progress = @total.zero? ? 0 : (100.0 * @done / @total).round(1)
    end
  end
end
