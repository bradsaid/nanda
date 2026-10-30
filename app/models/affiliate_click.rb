# One click on an affiliate "buy" button, recorded by AffiliateRedirectsController.
# Anonymous by design: product, store, where on the site, a mobile flag, and
# whether it looked automated. Clicks flagged suspected_bot are kept but left out
# of every admin figure except the "filtered" count.
class AffiliateClick < ApplicationRecord
  scope :since,     ->(time) { where(created_at: time..) }
  scope :counted,   -> { where(suspected_bot: false) }
  scope :suspected, -> { where(suspected_bot: true) }

  # True when the request doesn't look like a person clicking from one of our pages.
  def self.suspected_bot?(request) = AffiliateClickScreen.new(request).suspected_bot?

  def self.top_products(limit = 25)
    counted.group(:product_anchor, :product_name)
      .order(Arel.sql("COUNT(*) DESC"), :product_name)
      .limit(limit)
      .count
  end

  def self.by_placement
    counted.group(:placement).order(Arel.sql("COUNT(*) DESC")).count
  end
end
