# frozen_string_literal: true
require "roo"
require "net/http"
require "json"
require "uri"
require "set"

class ImportMissingAvatars
  IG_APP_ID     = "936619743392459"
  OPEN_TIMEOUT  = 10
  READ_TIMEOUT  = 10
  MAX_REDIRECTS = 3
  BASE_SLEEP    = 1.4

  # Pass cookie via ENV["IG_COOKIE"] or Rails.credentials.dig(:instagram, :cookie)
  def initialize(path:, sheet_name: nil, dry_run: false, logger: Rails.logger, cookie: nil)
    @path       = path
    @sheet_name = sheet_name
    @dry_run    = dry_run
    @logger     = logger
    @cookie     = cookie.presence || ENV["IG_COOKIE"].presence ||
                  (Rails.application.credentials.dig(:instagram, :cookie) rescue nil).to_s
  end

  def call
    raise "Missing IG cookie" if @cookie.blank?

    xlsx  = Roo::Excelx.new(@path)
    sheet = if @sheet_name && xlsx.sheets.include?(@sheet_name)
      xlsx.sheet(@sheet_name)
    else
      xlsx.sheet(xlsx.sheets.first)
    end

    header = sheet.row(1).map { |h| h.to_s.strip }
    fullname_idx  = header.index("FullName")
    instagram_idx = header.index("Instagram")
    raise "Column 'FullName' not found"  unless fullname_idx
    raise "Column 'Instagram' not found" unless instagram_idx

    # Preload who already has avatars to avoid N+1 checks
    has_avatar_ids = Survivor.joins(:avatar_attachment).pluck(:id).to_set

    updated = 0
    unchanged = 0
    not_found = 0
    missing_ig = 0
    skipped_existing = 0
    errors = 0

    ActiveRecord::Base.transaction do
      (2..sheet.last_row).each do |r|
        begin
          name = (sheet.cell(r, fullname_idx + 1)  || "").to_s.strip
          ig   = (sheet.cell(r, instagram_idx + 1) || "").to_s.strip
          next if name.blank?

          survivor = find_survivor(name)
          unless survivor
            not_found += 1
            @logger.warn "Row #{r}: NO MATCH in DB for #{name.inspect} → skip"
            next
          end

          # NEW: skip survivors that already have an attached avatar
          if has_avatar_ids.include?(survivor.id)
            skipped_existing += 1
            @logger.info "Row #{r}: SKIP (already has avatar) — #{survivor.id} #{survivor.full_name}"
            next
          end

          if ig.blank?
            missing_ig += 1
            @logger.info "Row #{r}: #{survivor.id} #{survivor.full_name} → no Instagram value → skip"
            next
          end

          username = extract_username(ig)
          if username.blank?
            unchanged += 1
            @logger.info "Row #{r}: #{survivor.id} #{survivor.full_name} → could not extract username from #{ig.inspect} → skip"
            next
          end

          res = fetch_ig_avatar(username)

          changes = {}
          # backfill instagram if DB blank
          changes[:instagram] = normalized_ig_url(ig) if survivor.instagram.blank? && ig.present?

          # (We’re only updating DB fields here — this version intentionally does not attach blobs)
          if res[:url].present? && survivor.avatar_url != res[:url]
            changes[:avatar_url] = res[:url]
          end

          if changes.any?
            survivor.update!(changes) unless @dry_run
            updated += 1
            @logger.info "Row #{r}: UPDATE #{survivor.id} #{survivor.full_name} → #{changes.keys.join(", ")} (#{res[:status]})"
          else
            unchanged += 1
            @logger.info "Row #{r}: UNCHANGED #{survivor.id} #{survivor.full_name}"
          end

          jitter_sleep
        rescue => e
          errors += 1
          @logger.error "Row #{r} ERROR: #{e.class} - #{e.message}"
        end
      end

      if @dry_run
        @logger.info "DRY RUN — rollback"
        raise ActiveRecord::Rollback
      end
    end

    @logger.info "Summary → updated: #{updated}, unchanged: #{unchanged}, not_found: #{not_found}, missing_ig: #{missing_ig}, skipped_existing: #{skipped_existing}, errors: #{errors}"
  end

  private

  def jitter_sleep(base = BASE_SLEEP)
    sleep(base * (0.7 + rand * 0.6))
  end

  def find_survivor(name)
    nm = name.to_s.strip.squeeze(" ")
    Survivor.find_by(full_name: nm) || Survivor.where("full_name ILIKE ?", nm).first
  end

  def normalized_ig_url(v)
    s = v.to_s.strip
    return s if s =~ %r{\Ahttps?://}i
    handle = s.sub(/\A@/, "")
    return "" if handle.blank?
    "https://www.instagram.com/#{handle}/"
  end

  def extract_username(instagram_url)
    u = URI.parse(instagram_url) rescue nil
    return nil unless u && u.host&.include?("instagram.com")
    u.path.split("/").reject(&:empty?).first.to_s.split("?").first
  end

  def http_get_with_redirects(uri, extra_headers = {}, limit: MAX_REDIRECTS)
    raise "Too many redirects" if limit < 0
    req = Net::HTTP::Get.new(uri)
    # Browser-like headers + cookie
    req["User-Agent"]      = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
    req["Accept"]          = "text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7"
    req["Accept-Language"] = "en-US,en;q=0.9"
    req["Referer"]         = "https://www.instagram.com/"
    req["Cookie"]          = @cookie
    extra_headers.each { |k, v| req[k] = v }

    Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == "https"),
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      res = http.request(req)
      if res.is_a?(Net::HTTPRedirection)
        loc = res["location"]
        return res unless loc
        new_uri = (URI.join("#{uri.scheme}://#{uri.host}", loc) rescue URI(loc))
        return http_get_with_redirects(new_uri, extra_headers, limit: limit - 1)
      end
      res
    end
  rescue
    nil
  end

  def extract_from_html(html)
    return { url: nil, private: false } unless html && !html.empty?
    private_hit = !!(html =~ /This Account is Private/i)

    if (m = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i))
      return { url: m[1], private: private_hit }
    end

    if (j = html.match(/<script type=["']application\/ld\+json["']>\s*(\{.*?\})\s*<\/script>/mi))
      ld = JSON.parse(j[1]) rescue nil
      if ld
        img = ld["image"].is_a?(String) ? ld["image"] : ld.dig("image", "url")
        return { url: img, private: private_hit } if img.present?
      end
    end

    { url: nil, private: private_hit }
  end

  def fetch_ig_avatar(username)
    return { url: nil, private: false, status: :not_found } if username.to_s.empty?

    # JSON endpoint first
    json_uri = URI("https://i.instagram.com/api/v1/users/web_profile_info/?username=#{username}")
    res = http_get_with_redirects(json_uri, { "X-IG-App-ID" => IG_APP_ID, "Accept" => "application/json" })
    if res&.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body) rescue nil
      user = data&.dig("data", "user")
      if user
        is_private = !!user["is_private"]
        url = user["profile_pic_url_hd"] || user["profile_pic_url"]
        return { url: url, private: is_private, status: (url.present? ? (is_private ? :private : :ok) : (is_private ? :private : :not_found)) }
      end
    end

    jitter_sleep

    # HTML
    html_uri = URI("https://www.instagram.com/#{username}/")
    res = http_get_with_redirects(html_uri)
    if res&.is_a?(Net::HTTPSuccess)
      info = extract_from_html(res.body)
      return { url: info[:url], private: info[:private], status: info[:url].present? ? (info[:private] ? :private : :ok) : (info[:private] ? :private : :not_found) }
    end

    jitter_sleep

    # Mirror
    mirror_uri = URI("https://r.jina.ai/http://www.instagram.com/#{username}/")
    res = http_get_with_redirects(mirror_uri)
    if res&.is_a?(Net::HTTPSuccess)
      info = extract_from_html(res.body)
      return { url: info[:url], private: info[:private], status: info[:url].present? ? (info[:private] ? :private : :ok) : (info[:private] ? :private : :not_found) }
    end

    { url: nil, private: false, status: :not_found }
  end
end
