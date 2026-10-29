# One click on an affiliate "buy" button, recorded by AffiliateRedirectsController.
# Anonymous by design: product, store, where on the site, and a mobile flag.
class AffiliateClick < ApplicationRecord
  scope :since, ->(time) { where(created_at: time..) }

  def self.top_products(limit = 25)
    group(:product_anchor, :product_name)
      .order(Arel.sql("COUNT(*) DESC"), :product_name)
      .limit(limit)
      .count
  end

  def self.by_placement
    group(:placement).order(Arel.sql("COUNT(*) DESC")).count
  end
end
