module Admin
  # Where affiliate buy-button clicks come from. Counts are anonymous (see AffiliateClick).
  class AffiliateClicksController < BaseController
    before_action :require_full_admin!

    def index
      @totals = {
        "Last 24 hours" => AffiliateClick.since(24.hours.ago).count,
        "Last 7 days"   => AffiliateClick.since(7.days.ago).count,
        "Last 30 days"  => AffiliateClick.since(30.days.ago).count,
        "All time"      => AffiliateClick.count
      }
      @top_products = AffiliateClick.top_products(25)
      @placements   = AffiliateClick.by_placement
      @recent       = AffiliateClick.order(created_at: :desc, id: :desc).limit(50)
    end
  end
end
