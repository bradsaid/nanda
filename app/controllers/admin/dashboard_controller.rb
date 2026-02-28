module Admin
  class DashboardController < BaseController
    def show
      @total_views   = PageView.count
      @today_views   = PageView.today.count
      @week_views    = PageView.this_week.count
      @month_views   = PageView.this_month.count

      @unique_today  = PageView.today.unique_visitors
      @unique_week   = PageView.this_week.unique_visitors
      @unique_month  = PageView.this_month.unique_visitors

      @avg_duration  = PageView.avg_duration

      @top_pages     = PageView.top_pages(25)
      @top_sections  = PageView.top_sections(20)
      @daily_counts  = PageView.daily_counts(30)
      @top_countries = PageView.top_countries(15)
      @top_browsers  = PageView.top_browsers(10)
      @device_breakdown = PageView.device_breakdown
      @top_referrers = PageView.top_referrer_domains(10)
      @time_by_page  = PageView.avg_duration_by_page(25)
      @recent_views  = PageView.recent(50)
    end
  end
end
