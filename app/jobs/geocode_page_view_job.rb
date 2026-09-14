# Resolves a page view's country/city from its IP outside the request cycle.
#
# This lookup used to run inline in TrackPageViews#record_page_view, so every
# visitor paid the geocoding provider's round trip before the response was
# released — and when the provider returned 503s (observed in production) the
# whole site slowed with it. The page view row is written immediately without
# geo, and this job fills it in afterwards.
class GeocodePageViewJob < ApplicationJob
  queue_as :default

  # The row is still useful without country/city, so a page view that was
  # deleted before the job ran is not worth raising over.
  discard_on ActiveJob::DeserializationError

  def perform(page_view_id)
    pv = PageView.find_by(id: page_view_id)
    return if pv.nil? || pv.ip_address.blank?
    return if pv.country.present?

    result = Geocoder.search(pv.ip_address).first
    return if result.nil?

    # update_columns: no validations or callbacks needed, and this must not
    # disturb created_at/updated_at that the dashboard buckets on.
    pv.update_columns(country: result.country.presence, city: result.city.presence)
  rescue StandardError => e
    Rails.logger.warn("GeocodePageViewJob failed for ##{page_view_id}: #{e.class} #{e.message}")
  end
end
