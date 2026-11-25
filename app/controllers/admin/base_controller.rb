module Admin
  class BaseController < ApplicationController
    skip_after_action :record_page_view
    noindex # the whole admin area (views also set the robots meta tag)

    before_action :require_admin_user
    before_action :set_paper_trail_whodunnit
    helper_method :current_admin, :full_admin?, :episode_editor?

    def user_for_paper_trail
      @current_admin&.email_address
    end

    private

    # 30-day page views per episode, { episode id => views }, for the traffic columns and
    # sort. Views are recorded under the URL that was served: /episodes/<slug> now, but
    # /episodes/<id> for everything before the slug URLs (and any numeric URL that still
    # slips through). Both count, and an old slug (history) counts for its episode.
    # Shared by the episode list and the synopsis queue; cached since PageView is large.
    def episode_traffic_by_id
      path_counts = Rails.cache.fetch("admin/episodes/traffic_counts/v2", expires_in: 5.minutes) do
        PageView.where(created_at: 30.days.ago..)
                .where("path ~ ?", '^/episodes/[^/]+$')
                .group(:path).count
      end
      segments = path_counts.transform_keys { |path| path.split("/").last.to_s }
      slugs    = segments.keys.reject { |seg| seg.match?(/\A\d+\z/) }
      id_by_slug = Episode.where(slug: slugs).pluck(:slug, :id).to_h
      missing    = slugs - id_by_slug.keys
      if missing.any?
        id_by_slug.merge!(FriendlyId::Slug.where(sluggable_type: "Episode", slug: missing).pluck(:slug, :sluggable_id).to_h)
      end
      segments.each_with_object(Hash.new(0)) do |(seg, count), h|
        id = seg.match?(/\A\d+\z/) ? seg.to_i : id_by_slug[seg].to_i
        h[id] += count if id.positive?
      end
    end

    # Goes through current_user like the rest of the site, so the persistent
    # remember-me cookie signs an admin in here too (it used to look only at
    # session[:user_id], which dies with the browser) and a banned account is
    # refused rather than waved through on a still-live session.
    def require_admin_user
      @current_admin = current_user
      unless @current_admin && (@current_admin.admin? || @current_admin.episode_editor?)
        redirect_to root_path, alert: "Not authorized."
      end
    end

    def require_full_admin!
      unless full_admin?
        redirect_to admin_episodes_path, alert: "Not authorized for that action."
      end
    end

    def current_admin
      @current_admin
    end

    def full_admin?
      @current_admin&.admin?
    end

    def episode_editor?
      @current_admin&.episode_editor?
    end
  end
end
