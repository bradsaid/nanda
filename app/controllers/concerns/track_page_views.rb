require "user_agent"

module TrackPageViews
  extend ActiveSupport::Concern

  included do
    after_action :record_page_view
  end

  private

  BOT_PATTERN = /bot|crawl|spider|slurp|bingpreview|mediapartners|facebookexternalhit|
    linkedinbot|twitterbot|applebot|duckduckbot|yandex|baidu|sogou|exabot|
    semrush|ahrefs|mj12bot|dotbot|rogerbot|screaming|archive\.org|
    headlesschrome|phantomjs|wget|curl|python-requests|go-http-client|
    pingdom|uptimerobot|statuscake|site24x7|googleother|petalbot|bytespider/ix.freeze

  def record_page_view
    return unless request.get?
    return if request.path.start_with?("/admin")
    return if request.path.match?(/\.(js|css|png|jpg|svg|ico|woff2?|map)\z/)
    return if request.user_agent.blank? || BOT_PATTERN.match?(request.user_agent)

    ua  = UserAgent.parse(request.user_agent.to_s)
    geo = geocode_ip(request.remote_ip)
    ref = request.referrer

    pv = PageView.create!(
      path:            request.path,
      controller_name: controller_name,
      action_name:     action_name,
      method:          request.method,
      ip_address:      request.remote_ip,
      user_agent:      request.user_agent&.truncate(500),
      referrer:        ref&.truncate(500),
      browser:         "#{ua.browser} #{ua.version}".strip.presence,
      os:              ua.os.to_s.presence,
      device_type:     ua.mobile? ? "Mobile" : "Desktop",
      visitor_id:      persistent_visitor_id,
      session_id:      page_view_session_id,
      referrer_domain: extract_domain(ref),
      country:         geo&.dig(:country),
      city:            geo&.dig(:city)
    )

    response.set_header("X-Page-View-Id", pv.id.to_s)
    cookies[:_pv_id] = { value: pv.id.to_s, path: "/", httponly: false }
  rescue StandardError => e
    Rails.logger.warn("PageView tracking failed: #{e.message}")
  end

  def persistent_visitor_id
    cookies[:_vid] ||= { value: SecureRandom.hex(16), expires: 1.year.from_now, httponly: true }
    cookies[:_vid]
  end

  def page_view_session_id
    session[:page_view_session_id] ||= SecureRandom.hex(16)
  end

  def extract_domain(url)
    return nil if url.blank?
    URI.parse(url).host
  rescue URI::InvalidURIError
    nil
  end

  def geocode_ip(ip)
    return nil if ip.blank? || ip == "127.0.0.1" || ip == "::1"
    result = Geocoder.search(ip).first
    return nil unless result
    { country: result.country, city: result.city.presence }
  rescue StandardError
    nil
  end
end
