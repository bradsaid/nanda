module TrackPageViews
  extend ActiveSupport::Concern

  included do
    after_action :record_page_view
  end

  private

  def record_page_view
    return unless request.get?
    return if request.path.start_with?("/admin")
    return if request.path.match?(/\.(js|css|png|jpg|svg|ico|woff2?|map)\z/)

    PageView.create!(
      path:            request.path,
      controller_name: controller_name,
      action_name:     action_name,
      method:          request.method,
      ip_address:      request.remote_ip,
      user_agent:      request.user_agent&.truncate(500),
      referrer:        request.referrer&.truncate(500)
    )
  rescue StandardError => e
    Rails.logger.warn("PageView tracking failed: #{e.message}")
  end
end
