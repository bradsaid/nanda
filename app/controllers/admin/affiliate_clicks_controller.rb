module Admin
  # Where affiliate buy-button clicks come from. Counts are anonymous (see AffiliateClick).
  class AffiliateClicksController < BaseController
    before_action :require_full_admin!

    def index
      counted = AffiliateClick.counted
      @totals = {
        "Last 24 hours" => counted.since(24.hours.ago).count,
        "Last 7 days"   => counted.since(7.days.ago).count,
        "Last 30 days"  => counted.since(30.days.ago).count,
        "All time"      => counted.count
      }
      @filtered_total  = AffiliateClick.suspected.count
      @filtered_recent = AffiliateClick.suspected.since(24.hours.ago).count
      @top_products = AffiliateClick.top_products(25)
      @placements   = AffiliateClick.by_placement
      @recent       = counted.order(created_at: :desc, id: :desc).limit(50)
    end
  end
end
