# Resolves a page view's country/city from its IP outside the request cycle.
#
# This lookup used to run inline in TrackPageViews#record_page_view, so every
# visitor paid the geocoding provider's round trip before the response was
# released — and when the provider returned 503s (observed in production) the
# whole site slowed with it. The page view row is written immediately without
# geo, and this job fills it in afterwards.
#
# Results are cached per IP. The provider's keyless tier allows only a few
# thousand lookups a day, and one Mac stuck reloading an episode page (88,000
# views from a single IP in October 2026) used that up within hours, so real
# visitors went un-geocoded until it reset. One lookup per address is plenty.
class GeocodePageViewJob < ApplicationJob
  queue_as :default

  CACHE_TTL = 30.days

  # The row is still useful without country/city, so a page view that was
  # deleted before the job ran is not worth raising over.
  discard_on ActiveJob::DeserializationError

  def perform(page_view_id)
    pv = PageView.find_by(id: page_view_id)
    return if pv.nil? || pv.ip_address.blank?
    return if pv.country.present?

    geo = Rails.cache.read(cache_key(pv.ip_address)) || lookup(pv.ip_address)
    return if geo.nil?

    # update_columns: no validations or callbacks needed, and this must not
    # disturb created_at/updated_at that the dashboard buckets on.
    pv.update_columns(country: geo[:country], city: geo[:city])
  rescue StandardError => e
    Rails.logger.warn("GeocodePageViewJob failed for ##{page_view_id}: #{e.class} #{e.message}")
  end

  private

  def lookup(ip)
    result = Geocoder.search(ip).first
    return if result.nil?

    geo = { country: result.country.presence, city: result.city.presence }
    # A rate-limited reply can come back as a result with no country; caching
    # that would leave the address blank for a month.
    Rails.cache.write(cache_key(ip), geo, expires_in: CACHE_TTL) if geo[:country]
    geo
  end

  def cache_key(ip)
    "geocode/ip/#{ip}"
  end
end
