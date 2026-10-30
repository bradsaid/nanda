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
