module Admin
  class DashboardController < BaseController
    def show
      @total_views   = PageView.count
      @today_views   = PageView.today.count
      @week_views    = PageView.this_week.count
      @month_views   = PageView.this_month.count
      @avg_per_day   = PageView.avg_views_per_day

      @unique_today  = PageView.today.unique_visitors
      @unique_week   = PageView.this_week.unique_visitors
      @unique_month  = PageView.this_month.unique_visitors

      @avg_duration  = PageView.avg_duration
      @visitor_frequency = PageView.unique_visitor_frequency

      @top_pages     = PageView.top_pages(25)
      @top_sections  = PageView.top_sections(20)
      @daily_counts  = PageView.daily_counts(7)
      @daily_uniques = PageView.daily_unique_counts(7)
      # Chart series cover every complete calendar day from the earliest
      # tracked PageView through yesterday (today is intentionally excluded so
      # a partial in-progress bucket doesn't visually dip the trailing edge —
      # see PageView.daily_counts for details). The view embeds the full
      # series and a client-side slider slices it down to whatever window
      # the admin wants (default 30 days).
      earliest = PageView.minimum(:created_at)&.in_time_zone&.to_date || Date.current
      @chart_total_days = [(Date.current - earliest).to_i, 1].max
      @chart_counts  = PageView.daily_counts(@chart_total_days)
      @chart_uniques = PageView.daily_unique_counts(@chart_total_days)
      @top_countries = PageView.top_countries(15)
      @device_breakdown = PageView.device_breakdown
      @top_referrers = PageView.top_referrer_domains(10)
      @direct_views  = PageView.where(referrer_domain: [nil, ""]).count
      @time_by_page  = PageView.avg_duration_by_page(10)
      @recent_views  = PageView.recent(50)
    end
  end
end
