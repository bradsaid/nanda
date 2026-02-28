module Admin
  class DashboardController < BaseController
    def show
      @total_views   = PageView.count
      @today_views   = PageView.today.count
      @week_views    = PageView.this_week.count
      @month_views   = PageView.this_month.count
      @top_pages     = PageView.top_pages(25)
      @top_sections  = PageView.top_sections(20)
      @daily_counts  = PageView.daily_counts(30)
      @recent_views  = PageView.recent(50)
    end
  end
end
