# lib/tasks/import_instagram_avatars.rake
# Usage:
#   IG_COOKIES='fbm_...; csrftoken=...; sessionid=...; ds_user_id=...' bundle exec rake insta:import_avatars
# Options:
#   XLSX=/absolute/path.xlsx OVERWRITE=1 VERBOSE=1 ONLY="part of name or @handle" LIMIT=100 MIN_DELAY=1.5 MAX_DELAY=3.0

require "roo"
require "nokogiri"
require "net/http"
require "uri"
require "tempfile"
require "json"

namespace :insta do
  desc "Import Instagram avatars for Survivors from ~/Desktop/avatars.xlsx"
  task import_avatars: :environment do
    DEFAULT_XLSX_PATH = File.expand_path("~/Desktop/avatars.xlsx")
    xlsx_path = (ENV["XLSX"].presence || DEFAULT_XLSX_PATH)

    IG_COOKIES = ENV["IG_COOKIES"].to_s.strip
    if IG_COOKIES.empty?
      puts "[FATAL] IG_COOKIES not set."
      exit(1)
    end
    unless IG_COOKIES.include?("sessionid=") && IG_COOKIES.include?("csrftoken=")
      puts "[WARN] Your cookies do not include sessionid= and csrftoken=; login redirects likely."
    end

    USER_AGENT = ENV["IG_UA"].presence || "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/537.36 (KHTML, like Gecko) Chrome Safari"
    OVERWRITE  = ENV["OVERWRITE"].to_s == "1"
    VERBOSE    = ENV["VERBOSE"].to_s == "1"
    ONLY       = ENV["ONLY"].to_s.strip.downcase.presence
    LIMIT      = (ENV["LIMIT"].presence || 0).to_i
    MIN_DELAY  = (ENV["MIN_DELAY"] || "2.0").to_f
    MAX_DELAY  = (ENV["MAX_DELAY"] || "4.5").to_f

    NAME_CANDIDATES = [/^full[_\s-]*name$/i, /^name$/i, /survivor/i]
    IG_CANDIDATES   = [/instagram/i, /\big[_\s-]*handle/i, /^ig$/i, /^handle$/i, /insta/i, /instagram[_\s-]*url/i]

    # ---------- helpers ----------
    def find_col_index(headers, patterns)
      headers.index { |h| patterns.any? { |re| h.to_s.strip =~ re } }
    end

    def extract_username(raw)
      return nil if raw.blank?
      s = raw.to_s.strip
      s = s.sub(/\A@/, "")
      if s =~ %r{instagram\.com/([^/?#\s]+)}i
        return $1
      end
      s.sub(%r{/\z}, "")
    end

    def http_fetch(uri_str, cookies:, user_agent:, extra_headers: {}, max_redirects: 6)
      current_uri = URI.parse(uri_str)
      redirects = 0
      loop do
        req = Net::HTTP::Get.new(current_uri)
        req["Cookie"]          = cookies if cookies && !cookies.empty?
        req["User-Agent"]      = user_agent
        req["Accept"]          = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        req["Accept-Language"] = "en-US,en;q=0.9"
        req["Referer"]         = "https://www.instagram.com/"
        extra_headers.each { |k,v| req[k] = v }

        resp = Net::HTTP.start(current_uri.host, current_uri.port, use_ssl: (current_uri.scheme == "https")) do |http|
          http.read_timeout = 20
          http.open_timeout = 10
          http.request(req)
        end

        case resp
        when Net::HTTPRedirection
          location = resp["location"].to_s
          return [resp, current_uri, location] if redirects >= max_redirects || location.empty?
          next_uri = URI.parse(location) rescue nil
          next_uri = URI.join(current_uri, location) if next_uri && next_uri.relative?
          next_uri ||= current_uri # safety
          redirects += 1
          current_uri = next_uri
          next
        else
          return [resp, current_uri, nil]
        end
      end
    end

    def parse_avatar_url_from_html(html)
      doc = Nokogiri::HTML(html)
      og = doc.at('meta[property="og:image"]')&.[]("content")
      return og if og.present?

      if (m = html.match(/"profile_pic_url_hd"\s*:\s*"([^"]+)"/))
        return m[1].gsub(/\\u0026/, "&").gsub(/\\\//, "/")
      end
      if (m = html.match(/"profile_pic_url"\s*:\s*"([^"]+)"/))
        return m[1].gsub(/\\u0026/, "&").gsub(/\\\//, "/")
      end
      nil
    end

    def fetch_avatar_url(username, cookies:, user_agent:, verbose: false)
      # 1) Official web JSON endpoint
      json_url = "https://www.instagram.com/api/v1/users/web_profile_info/?username=#{username}"
      headers  = { "X-IG-App-ID" => "936619743392459" } # public web app id
      resp, final_uri, loc = http_fetch(json_url, cookies: cookies, user_agent: user_agent, extra_headers: headers)
      if resp.is_a?(Net::HTTPSuccess)
        if resp["content-type"].to_s.include?("application/json")
          begin
            data = JSON.parse(resp.body)
            url = data.dig("data", "user", "profile_pic_url_hd") || data.dig("data", "user", "profile_pic_url")
            return [url, nil] if url.present?
          rescue => e
            return [nil, "JSON parse error: #{e.message}"]
          end
        end
      elsif resp.is_a?(Net::HTTPRedirection)
        if (loc.to_s.include?("/accounts/login") || loc.to_s.include?("/challenge"))
          return [nil, "login/challenge redirect on JSON endpoint (cookies rejected)"]
        end
      elsif resp.code == "404"
        return [nil, "username not found (404 on JSON endpoint)"]
      end

      # 2) HTML fallback
      profile_url = "https://www.instagram.com/#{username}/"
      verbose && puts("       GET #{profile_url}")
      resp, _u, loc = http_fetch(profile_url, cookies: cookies, user_agent: user_agent)
      if resp.is_a?(Net::HTTPSuccess)
        url = parse_avatar_url_from_html(resp.body)
        return [url, nil] if url.present?
        return [nil, "avatar URL not in HTML"]
      elsif resp.is_a?(Net::HTTPRedirection)
        if loc.to_s.include?("/accounts/login") || loc.to_s.include?("/challenge")
          return [nil, "login/challenge redirect (cookies invalid/expired)"]
        end
        return [nil, "HTTP #{resp.code} redirect → #{loc}"]
      else
        return [nil, "HTTP #{resp.code} on profile"]
      end
    end

    def download_to_tempfile(url, cookies:, user_agent:)
      resp, _u, loc = http_fetch(url, cookies: cookies, user_agent: user_agent)
      if resp.is_a?(Net::HTTPRedirection)
        return [nil, "image redirect → #{loc} (unexpected)"]
      end
      return [nil, "HTTP #{resp.code} when fetching image"] unless resp.is_a?(Net::HTTPSuccess)

      ext =
        case resp["content-type"].to_s
        when /png/i  then ".png"
        when /webp/i then ".webp"
        when /jpeg/i, /jpg/i then ".jpg"
        else
          File.extname(URI(url).path).presence || ".jpg"
        end

      tf = Tempfile.new(["avatar", ext], binmode: true)
      tf.write(resp.body)
      tf.rewind
      [tf, nil]
    end

    # ---------- spreadsheet ----------
    unless File.exist?(xlsx_path)
      puts "[FATAL] XLSX not found: #{xlsx_path}"
      exit(1)
    end

    puts "[INFO] Sheet: #{xlsx_path}"
    xls = Roo::Spreadsheet.open(xlsx_path, extension: :xlsx)
    sheet = xls.sheet(0)

    headers = sheet.row(1).map { |h| h.to_s.strip }
    name_idx = find_col_index(headers, NAME_CANDIDATES)
    ig_idx   = find_col_index(headers, IG_CANDIDATES)
    if name_idx.nil? || ig_idx.nil?
      puts "[FATAL] Missing required columns. Headers: #{headers.inspect}"
      exit(1)
    end

    total = 0; ok = 0; skipped = 0; failed = 0
    processed = 0

    (2..sheet.last_row).each do |row_num|
      row        = sheet.row(row_num)
      full_name  = row[name_idx].to_s.strip
      ig_raw     = row[ig_idx].to_s.strip
      printable  = full_name.presence || "(no name)"
      next unless full_name.present?

      if ONLY && !(full_name.downcase.include?(ONLY) || ig_raw.downcase.include?(ONLY))
        next
      end
      if LIMIT > 0 && processed >= LIMIT
        break
      end
      processed += 1
      total += 1

      survivor = Survivor.where("LOWER(full_name) = ?", full_name.downcase).first
      unless survivor
        puts "[FAIL] Row #{row_num} (#{printable}): Survivor not found"
        failed += 1
        next
      end

      if ig_raw.blank?
        puts "[FAIL] Row #{row_num} (#{printable}): Missing Instagram handle/URL"
        failed += 1
        next
      end

      if survivor.avatar.attached? && !OVERWRITE
        puts "[SKIP] Row #{row_num} (#{printable}): Avatar exists (use OVERWRITE=1)"
        skipped += 1
        next
      end

      username = extract_username(ig_raw)
      if username.blank?
        puts "[FAIL] Row #{row_num} (#{printable}): Could not parse username from '#{ig_raw}'"
        failed += 1
        next
      end

      avatar_url, why = fetch_avatar_url(username, cookies: IG_COOKIES, user_agent: USER_AGENT, verbose: VERBOSE)
      if avatar_url.blank?
        puts "[FAIL] Row #{row_num} (#{printable} → @#{username}): #{why || 'no avatar url'}"
        failed += 1
        next
      end

      tf, err = download_to_tempfile(avatar_url, cookies: IG_COOKIES, user_agent: USER_AGENT)
      if tf.nil?
        puts "[FAIL] Row #{row_num} (#{printable} → @#{username}): #{err}"
        failed += 1
        next
      end

      begin
        filename = "#{username}#{File.extname(tf.path)}"
        content_type =
          case File.extname(tf.path).downcase
          when ".png"  then "image/png"
          when ".webp" then "image/webp"
          when ".jpg", ".jpeg" then "image/jpeg"
          else "image/jpeg"
          end

        survivor.avatar.purge if survivor.avatar.attached? && OVERWRITE
        survivor.avatar.attach(io: tf, filename: filename, content_type: content_type)
        survivor.touch
        puts "[OK]   Row #{row_num} (#{printable} → @#{username}): Attached #{filename}"
        ok += 1
      rescue => e
        puts "[FAIL] Row #{row_num} (#{printable}): Attach failed - #{e.class}: #{e.message}"
        failed += 1
      ensure
        tf.close! rescue nil
      end

      sleep(rand(MIN_DELAY..MAX_DELAY))
    end

    puts "------------------------------------------------------------------"
    puts "[DONE] Scanned: #{total} | OK: #{ok} | Skipped: #{skipped} | Failed: #{failed}"
    puts "       Source: #{xlsx_path} | Overwrite: #{OVERWRITE ? 'yes' : 'no'} | Verbose: #{VERBOSE ? 'yes' : 'no'}"
  end
end
