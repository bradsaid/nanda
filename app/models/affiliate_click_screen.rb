require "openssl"

# Decides whether a /go/ click looks like a person using a browser on our site.
# Anything that doesn't is still redirected (and still stored), but flagged
# suspected_bot so the admin report leaves it out.
#
# Nothing identifying is kept: the only IP-derived value is a salted HMAC used as
# a cache key for one minute (see #rate_limited?), never written to the database.
#
# Usage: AffiliateClickScreen.new(request).reasons  # => [] for a real-looking click
class AffiliateClickScreen
  # HTTP libraries and automation tools that don't call themselves bots. The
  # known-crawler list (TrackPageViews::BOT_PATTERN) is checked first and those
  # clicks aren't stored at all; this catches the rest.
  AUTOMATION_PATTERN = %r{
    headless|phantomjs|selenium|webdriver|playwright|puppeteer|cypress|
    python-requests|python-urllib|python/\d|aiohttp|httpx|urllib|
    go-http-client|okhttp|\bjava[/\s-]|apache-httpclient|libwww|perl|
    axios|node-fetch|node-superfetch|undici|\bnode\b|got\s\(|
    scrapy|mechanize|curl|wget|httpie|postman|insomnia|restsharp|guzzle|
    reqwest|faraday|jsdom|http[-_]?client|python|ruby
  }ix.freeze

  # Hosts that count as "this site" for the Referer check, besides the host the
  # request itself arrived on (which covers the herokuapp host and localhost).
  SELF_HOSTS = %w[nakedandafraidfan.com].freeze

  RATE_LIMIT  = 5     # more than this many /go/ requests...
  RATE_WINDOW = 60    # ...from one IP within this many seconds is flagged

  def self.rate_salt
    @rate_salt ||= Rails.application.key_generator.generate_key("affiliate-click-rate")
  end

  def initialize(request)
    @request = request
  end

  # Why the click looks automated; empty when it looks like a person.
  def reasons
    list = []
    list << :blank_user_agent if user_agent.blank?
    list << :automation_user_agent if user_agent.present? && AUTOMATION_PATTERN.match?(user_agent)
    list << :no_referer if @request.referer.blank?
    list << :foreign_referer if @request.referer.present? && !same_site_referer?
    list << :origin_only_referer if origin_only_referer?
    list << :sec_fetch_mismatch if sec_fetch_mismatch?
    list << :missing_browser_headers if missing_browser_headers?
    list << :rate_limited if rate_limited?
    list
  end

  def suspected_bot? = reasons.any?

  # Path (no host, no query, no fragment) of our own page the click came from;
  # nil for a missing, malformed or external Referer.
  def referring_path
    return unless same_site_referer?
    URI.parse(@request.referer.to_s).path.to_s.truncate(200).presence
  rescue URI::InvalidURIError
    nil
  end

  def same_site_referer?
    uri = URI.parse(@request.referer.to_s)
    return false unless uri.is_a?(URI::HTTP) && uri.host.present?
    allowed_hosts.include?(strip_www(uri.host))
  rescue URI::InvalidURIError
    false
  end

  # A same-site Referer with no path at all ("https://host", "https://host?x=1").
  #
  # The buy buttons carry referrerpolicy="same-origin", so a browser clicking one
  # sends the FULL URL of the page it is on, and that always has a path, even the
  # home page ("https://host/" -> "/"). A bare origin with nothing after the host
  # is what scripts send when they fake a Referer. Note the literal "/" is a real
  # path and is NOT flagged here. A script sending "https://host/" is
  # indistinguishable from the home page by this rule alone (the Sec-Fetch and
  # header checks below are the only other defence against it).
  def origin_only_referer?
    same_site_referer? && referring_path.blank?
  end

  # Browsers that implement Fetch Metadata (Chrome/Edge 76+, Firefox 90+, Safari
  # 16.4+) label every request. A click from one of our own pages is "same-origin"
  # ("same-site" is also tolerated in case a page is served from a sibling host).
  # "none" (typed URL, bookmark) or "cross-site" can't be a click on our button.
  # Only judged when the header is present: older browsers simply don't send it.
  def sec_fetch_mismatch?
    site = @request.get_header("HTTP_SEC_FETCH_SITE").to_s.strip.downcase
    site.present? && !%w[same-origin same-site].include?(site)
  end

  # No Sec-Fetch-Site AND no Accept-Language. Every browser sends Accept-Language,
  # and every current one sends Sec-Fetch-Site, so having neither is a script
  # that only copied User-Agent/Referer. Accept-Language missing on its own is
  # NOT flagged (privacy tools can strip it); it only counts alongside the
  # missing Sec-Fetch-Site.
  def missing_browser_headers?
    @request.get_header("HTTP_SEC_FETCH_SITE").to_s.strip.blank? &&
      @request.get_header("HTTP_ACCEPT_LANGUAGE").to_s.strip.blank?
  end

  private

  def user_agent = @request.user_agent.to_s

  def allowed_hosts
    (SELF_HOSTS + [@request.host]).map { |h| strip_www(h) }
  end

  def strip_www(host) = host.to_s.downcase.sub(/\Awww\./, "")

  # Counts this request against the caller's IP in a one-minute bucket. The IP is
  # only ever hashed (with a server-side secret) into a short-lived cache key.
  def rate_limited?
    ip = @request.remote_ip.to_s
    return false if ip.blank?
    bucket = Time.now.to_i / RATE_WINDOW
    key    = "affiliate-click-rate:#{bucket}:#{OpenSSL::HMAC.hexdigest('SHA256', self.class.rate_salt, ip)}"
    count  = Rails.cache.increment(key, 1, expires_in: RATE_WINDOW * 2)
    count.to_i > RATE_LIMIT
  rescue StandardError => e
    Rails.logger.warn("AffiliateClick rate guard failed: #{e.class}")
    false
  end
end
