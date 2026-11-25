# Branded error pages, rendered through the site layout.
#
# config/application.rb points `config.exceptions_app` at this action. When a
# request raises (RoutingError, RecordNotFound, a failed CSRF check, a bug...),
# ActionDispatch::ShowExceptions rewrites PATH_INFO to "/<status>" and calls it,
# so there is deliberately no route: the status code is read from the path.
#
# Safety rules:
#   * The response status is always the real error status (404 stays 404, never
#     a "soft 404"), and the page is noindex (meta tag + X-Robots-Tag).
#   * Rendering the full layout touches the database (current user, etc.), which
#     may be exactly what is broken on a 500. If anything raises, fall back to the
#     static page in public/, which needs nothing.
#   * It is not counted as a page view and never carries ads.
class ErrorsController < ApplicationController
  # The exceptions app is handed the ORIGINAL request, which may be a POST that
  # failed its CSRF check; re-verifying the token here would just raise again.
  skip_forgery_protection
  skip_after_action :record_page_view
  noindex

  COPY = {
    400 => [ "That request didn't make sense", "Something about that link or form submission was malformed." ],
    404 => [ "We couldn't find that page", "The address may be mistyped, or the page may have moved or been removed." ],
    406 => [ "We can't show that page that way", "Your browser asked for a format this page doesn't offer." ],
    422 => [ "That change was rejected", "Your session may have expired. Go back, refresh the page and try again." ]
  }.freeze
  SERVER_COPY = [ "Something went wrong on our end", "It isn't you. We've been notified and will look into it. Please try again in a bit." ].freeze
  CLIENT_COPY = [ "Something went wrong with that request", "Please go back and try again, or use the links below." ].freeze

  # Static pages in public/ used when the full layout cannot render.
  STATIC_FALLBACKS = { 400 => "400", 404 => "404", 422 => "422", 500 => "500" }.freeze

  helper_method :error_status

  def show
    @error_page = true
    return render_non_html if non_html_request?

    @heading, @message = COPY.fetch(error_status) { error_status >= 500 ? SERVER_COPY : CLIENT_COPY }
    render "errors/show", layout: "application", status: error_status, formats: [ :html ]
  rescue StandardError => e
    Rails.logger.error("ErrorsController fell back to the static page: #{e.class}: #{e.message}")
    render_static_fallback unless performed?
  end

  private

  # "/404" -> 404. Anything unexpected is treated as a 500 rather than trusted.
  def error_status
    @error_status ||= begin
      code = request.path_info.to_s[%r{\A/(\d{3})\z}, 1].to_i
      code.between?(400, 599) ? code : 500
    end
  end

  def non_html_request?
    format = request.format
    !(format.nil? || format.html? || format == Mime::ALL)
  rescue StandardError # e.g. a malformed Accept header: answer with the HTML page
    false
  end

  def render_non_html
    text = "#{error_status} #{Rack::Utils::HTTP_STATUS_CODES[error_status]}"
    if request.format&.json?
      render json: { status: error_status, error: text }, status: error_status
    else
      render plain: text, status: error_status
    end
  end

  def render_static_fallback
    name = STATIC_FALLBACKS[error_status] || (error_status >= 500 ? "500" : "400")
    html = Rails.public_path.join("#{name}.html").read
    render html: html.html_safe, layout: false, status: error_status
  end
end
