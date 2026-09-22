# Rack::Attack — throttle abusive traffic on the auth + forum surfaces.
#
# Rules focus on the endpoints most likely to be targeted by bots:
#   - Signup + login + password reset
#   - Forum post creation
#
# Throttled requests get a 429 with a plain-text body. Blocked requests
# (repeat offenders) get 403. Legitimate visitors are never touched.
#
# The cache store defaults to `Rails.cache` which is Solid Cache in prod.

class Rack::Attack
  # Disable in test env so integration specs don't get blocked by empty-UA
  # or per-IP throttle rules that would trip on repeated fake requests.
  Rack::Attack.enabled = false if Rails.env.test?

  Rack::Attack.cache.store = Rails.cache

  ### Throttle: signup
  # Cap at 5 signups per IP per hour. Bot signup floods are the primary
  # abuse case once /signup exists.
  throttle("signups/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/signup" && req.post?
  end

  ### Throttle: login attempts
  # Cap at 10 login attempts per IP per 5 minutes.
  throttle("logins/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.path == "/session" && req.post?
  end

  ### Throttle: password reset requests
  throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/passwords" && req.post?
  end

  ### Throttle: forum posts per user
  # Cap at 30 posts per user per hour (a very active user might approach
  # this on an unusually busy thread but shouldn't exceed it).
  throttle("forum_posts/user", limit: 30, period: 1.hour) do |req|
    if req.post? && req.path.start_with?("/forum/") && req.env["rack.session"]
      req.env["rack.session"]["user_id"]
    end
  end

  ### Throttle: any forum request per IP
  # Prevents a single IP from scraping the forum aggressively.
  throttle("forum/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/forum")
  end

  ### Throttle: page reads per IP
  # The forum had a throttle; the wiki itself had none, so a scraper could pull
  # /items, /episodes and /survivors as fast as it liked — and those are the
  # expensive pages, several hundred milliseconds of aggregate queries each.
  # One OVH host fetched 97 pages in 8 seconds, 35 of them in a single second.
  #
  # Two tiers: a burst rule that catches exactly that, and a sustained rule for
  # a scraper that paces itself. Both are far above human browsing — clicking
  # steadily is perhaps 20 requests a minute — and above a polite crawler, so
  # ordinary visitors and Googlebot never see them.
  #
  # Assets and image variants are excluded: one page of avatars can fire dozens
  # of those, and counting them would throttle a genuine reader.
  PAGE_REQUEST = lambda do |req|
    next false unless req.get?
    path = req.path
    next false if path.start_with?("/assets", "/rails/active_storage", "/page_view_ping")
    next false if path.match?(/\.(js|css|png|jpe?g|gif|svg|ico|webp|woff2?|map|xml|txt)\z/i)
    true
  end

  throttle("pages/ip/burst", limit: 30, period: 10.seconds) do |req|
    req.ip if PAGE_REQUEST.call(req)
  end

  throttle("pages/ip/sustained", limit: 150, period: 1.minute) do |req|
    req.ip if PAGE_REQUEST.call(req)
  end

  ### Blocklist: obvious junk User-Agents
  # Empty UA or a curl UA against POST endpoints is almost always a bot.
  blocklist("no_ua_on_writes") do |req|
    (req.post? || req.put? || req.delete?) && req.user_agent.to_s.strip.empty?
  end

  ### Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period] || 60
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      ["Too many requests. Please slow down and try again in a moment.\n"]
    ]
  end
end
