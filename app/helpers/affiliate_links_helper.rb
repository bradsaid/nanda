# Buy buttons go through our own /go/:anchor redirect so clicks can be counted.
module AffiliateLinksHelper
  # controller_path => short placement label shown in the admin report
  PLACEMENTS = {
    "home"          => "home",
    "shop"          => "shop",
    "shop_guides"   => "guide",
    "items"         => "item",
    "survivors"     => "survivor",
    "seasons"       => "season",
    "locations"     => "location",
    "forum/topics"  => "forum"
  }.freeze

  # Where on the site a product card is being rendered, derived from the request.
  def affiliate_placement
    if controller_path == "episodes"
      return { "show" => "episode", "by_country" => "country" }.fetch(action_name, "location")
    end
    PLACEMENTS.fetch(controller_path, "other")
  end

  # Internal tracked URL for one of a product's buy buttons. `index` is the
  # position within ShopCatalog.buy_links(product).
  def tracked_buy_path(product, index, placement = nil)
    params = { from: placement.presence || affiliate_placement }
    params[:store] = index if index.positive?
    go_path(ShopCatalog.anchor(product), params)
  end
end
