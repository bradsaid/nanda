# GET /go/:slug[?store=N&from=placement]   (:slug is the product's ShopCatalog.anchor;
# it can't be named :anchor, which Rails reserves for the URL #fragment)
#
# Counts a click on a catalog product's buy button, then 302s to the catalog's
# own buy URL (Associates tag included). The destination is always looked up in
# ShopCatalog from the anchor, never taken from the request, so this cannot be
# used as an open redirect.
class AffiliateRedirectsController < ApplicationController
  # Redirect hops are not page views.
  skip_after_action :record_page_view

  PLACEMENT_FORMAT = /\A[a-z][a-z0-9_]{0,29}\z/

  def show
    product = ShopCatalog.products.find { |p| ShopCatalog.anchor(p) == params[:slug].to_s }
    return head(:not_found) unless product

    links = ShopCatalog.buy_links(product)
    link  = links[params[:store].to_s =~ /\A\d+\z/ ? params[:store].to_i : 0]
    url   = link && ShopCatalog.buy_url(link)
    return head(:not_found) unless url.to_s.match?(%r{\Ahttps?://[^/\s]+})

    record_click(product, link, url)

    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Robots-Tag"]  = "noindex, nofollow"
    redirect_to url, allow_other_host: true, status: :found
  end

  private

  # Known crawlers are redirected but not stored. Anything else is stored; clicks
  # that don't look like a person on one of our pages are flagged suspected_bot so
  # the admin report leaves them out. The redirect itself never depends on this.
  def record_click(product, link, url)
    return if known_bot?

    screen = AffiliateClickScreen.new(request)
    reasons = screen.reasons

    AffiliateClick.create!(
      product_anchor:   ShopCatalog.anchor(product),
      product_name:     product[:product].to_s.truncate(250),
      item:             product[:item].to_s.truncate(100).presence,
      store:            (ShopCatalog.amazon?(link) ? "amazon" : ShopCatalog.store_name(link)).to_s.truncate(100),
      destination_host: URI.parse(url).host.to_s.truncate(100),
      placement:        params[:from].to_s[PLACEMENT_FORMAT],
      referring_path:   screen.referring_path,
      is_mobile:        UserAgent.parse(request.user_agent.to_s).mobile? ? true : false,
      suspected_bot:    reasons.any?
    )
    Rails.logger.info("AffiliateClick flagged suspected_bot: #{reasons.join(',')}") if reasons.any?
  rescue StandardError => e
    Rails.logger.warn("AffiliateClick tracking failed: #{e.message}")
  end

  def known_bot?
    request.user_agent.present? && TrackPageViews::BOT_PATTERN.match?(request.user_agent)
  end
end
