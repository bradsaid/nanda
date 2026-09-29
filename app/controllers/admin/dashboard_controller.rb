module Admin
  class DashboardController < BaseController
    def show
      @total_views   = PageView.site.count
      @today_views   = PageView.site.today.count
      @week_views    = PageView.site.this_week.count
      @month_views   = PageView.site.this_month.count
      @avg_per_day   = PageView.site.avg_views_per_day

      @unique_today  = PageView.site.today.unique_visitors
      @unique_week   = PageView.site.this_week.unique_visitors
      @unique_month  = PageView.site.this_month.unique_visitors

      @avg_duration  = PageView.site.avg_duration
      @visitor_frequency = PageView.site.unique_visitor_frequency

      @top_pages     = PageView.site.top_pages(25)
      @top_sections  = PageView.site.top_sections(20)
      @daily_counts  = PageView.site.daily_counts(7)
      @daily_uniques = PageView.site.daily_unique_counts(7)
      # Chart series cover every complete calendar day from the earliest
      # tracked PageView through yesterday (today is intentionally excluded so
      # a partial in-progress bucket doesn't visually dip the trailing edge —
      # see PageView.site.daily_counts for details). The view embeds the full
      # series and a client-side slider slices it down to whatever window
      # the admin wants (default 30 days).
      earliest = PageView.site.minimum(:created_at)&.in_time_zone&.to_date || Date.current
      @chart_total_days = [(Date.current - earliest).to_i, 1].max
      @chart_counts  = PageView.site.daily_counts(@chart_total_days)
      @chart_uniques = PageView.site.daily_unique_counts(@chart_total_days)
      @top_countries = PageView.site.top_countries(15)
      @device_breakdown = PageView.device_breakdown
      @top_referrers = PageView.top_referrer_domains(10)
      @direct_views  = PageView.where(referrer_domain: [nil, ""]).count
      @time_by_page  = PageView.avg_duration_by_page(10)
      @recent_views  = PageView.recent(50)

      # Forum counters change slowly enough that a 60s cache is invisible to
      # the admin but skips 3 aggregate scans per dashboard render. Open
      # reports also caches — a moderator seeing a fresh report 60s late is
      # fine, and the "Open reports" card links straight to the queue anyway.
      # Forum traffic, reported on its own. Cached alongside the other forum
      # counters — a minute stale is invisible and this is a handful of aggregates.
      @forum_traffic = Rails.cache.fetch("admin/dashboard/forum_traffic/v1", expires_in: 60.seconds) do
        {
          today:        PageView.in_forum.today.count,
          week:         PageView.in_forum.this_week.count,
          unique_today: PageView.in_forum.today.unique_visitors,
          unique_week:  PageView.in_forum.this_week.unique_visitors,
          top_pages:    PageView.in_forum.top_pages(10)
        }
      end

      @forum_open_reports, @forum_topics_last_24h, @forum_posts_last_24h =
        Rails.cache.fetch("admin/dashboard/forum_counts/v2", expires_in: 60.seconds) do
          [
            ::Forum::Report.status_open.count,
            ::Forum::Topic.active.where(created_at: 24.hours.ago..).count,
            # Removed posts should not be counted, and neither should live posts
            # inside a removed topic — nobody can read either.
            ::Forum::Post.active
                         .joins(:forum_topic)
                         .where(forum_topics: { deleted_at: nil })
                         .where(forum_posts: { created_at: 24.hours.ago.. })
                         .count
          ]
        end
    end
  end
end
