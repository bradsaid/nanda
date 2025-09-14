# frozen_string_literal: true
# Retries rows with Photo == "Not found" (or blank), marks private profiles,
# and writes <input>_retry.xlsx

require "roo"
require "write_xlsx"
require "net/http"
require "json"
require "uri"

INPUT  = ARGV[0] || File.expand_path("~/Desktop/avatars_photos.xlsx")
OUTPUT = INPUT.sub(/\.xlsx\z/i, "_retry.xlsx")

# --- Put your Instagram cookie string here ---
IG_COOKIE = <<~COOKIE.strip
  fbm_124024574287414=base_domain=.instagram.com; ig_did=F826FBAD-28D8-4201-B029-C81FE8D0DEDE; datr=aikvaFcqn50Wjczn_GpoNdP7; mid=aKeHuwAEAAHyNuAS7zZLK9jLZfSM; ig_nrcb=1; csrftoken=ztSAtixZnBcyE6Z4thJYCJXvPJCuTwl4; ds_user_id=267019190; sessionid=267019190%3AKUG5sZC7Sv9P28%3A14%3AAYj8bhISIoRJrY9rEZCryZWQVIvvnPA4wzgI6jGjFQ
COOKIE


# --- Tunables ---
IG_APP_ID     = "936619743392459"
OPEN_TIMEOUT  = 10
READ_TIMEOUT  = 10
MAX_REDIRECTS = 3
BASE_SLEEP    = 1.4

def jitter_sleep(base = BASE_SLEEP)
  sleep(base * (0.7 + rand * 0.6))
end

def extract_username(instagram_url)
  u = URI(instagram_url) rescue nil
  return nil unless u && u.host&.include?("instagram.com")
  name = u.path.split("/").reject(&:empty?).first.to_s
  name.split("?").first
end

def http_get_with_redirects(uri, extra_headers = {}, limit: MAX_REDIRECTS)
  raise "Too many redirects" if limit < 0
  req = Net::HTTP::Get.new(uri)
  # Browser-like headers
  req["User-Agent"]      = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
  req["Accept"]          = "text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7"
  req["Accept-Language"] = "en-US,en;q=0.9"
  req["Referer"]         = "https://www.instagram.com/"
  req["Cookie"]          = IG_COOKIE
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
    return res
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
    begin
      ld = JSON.parse(j[1]) rescue nil
      if ld
        img = ld["image"].is_a?(String) ? ld["image"] : ld.dig("image", "url")
        return { url: img, private: private_hit } if img && !img.empty?
      end
    rescue
    end
  end

  { url: nil, private: private_hit }
end

def fetch_ig_avatar(username)
  return { url: nil, private: false, status: :not_found } if username.to_s.empty?

  # Try JSON endpoint
  json_uri = URI("https://i.instagram.com/api/v1/users/web_profile_info/?username=#{username}")
  res = http_get_with_redirects(json_uri, { "X-IG-App-ID" => IG_APP_ID, "Accept" => "application/json" })
  if res&.is_a?(Net::HTTPSuccess)
    begin
      data = JSON.parse(res.body)
      user = data.dig("data", "user")
      if user
        is_private = !!user["is_private"]
        url = user["profile_pic_url_hd"] || user["profile_pic_url"]
        return { url: url, private: is_private, status: is_private ? :private : :ok } if url && !url.empty?
        return { url: nil, private: is_private, status: is_private ? :private : :not_found }
      end
    rescue
    end
  end

  jitter_sleep

  # Try HTML
  html_uri = URI("https://www.instagram.com/#{username}/")
  res = http_get_with_redirects(html_uri)
  if res&.is_a?(Net::HTTPSuccess)
    info = extract_from_html(res.body)
    return { url: info[:url], private: info[:private], status: info[:url] ? (info[:private] ? :private : :ok) : (info[:private] ? :private : :not_found) }
  end

  jitter_sleep

  # Try mirror
  mirror_uri = URI("https://r.jina.ai/http://www.instagram.com/#{username}/")
  res = http_get_with_redirects(mirror_uri)
  if res&.is_a?(Net::HTTPSuccess)
    info = extract_from_html(res.body)
    return { url: info[:url], private: info[:private], status: info[:url] ? (info[:private] ? :private : :ok) : (info[:private] ? :private : :not_found) }
  end

  { url: nil, private: false, status: :not_found }
end

# --- Read input ---
xlsx = Roo::Excelx.new(INPUT)
sheet_name = xlsx.sheets.first
xlsx.default_sheet = sheet_name

headers   = xlsx.row(1).map { |h| h.to_s.strip }
insta_idx = headers.index("Instagram")
photo_idx = headers.index("Photo")
raise "Column 'Instagram' not found" unless insta_idx
raise "Column 'Photo' not found"     unless photo_idx

last_row = xlsx.last_row

# --- Writer ---
wb = WriteXLSX.new(OUTPUT)
ws = wb.add_worksheet(sheet_name || "Sheet1")

headers.each_with_index { |h, c| ws.write(0, c, h) }

# --- Process ---
(2..last_row).each do |r|
  row_vals = xlsx.row(r).dup
  url_cell = row_vals[insta_idx].to_s.strip
  photo    = row_vals[photo_idx].to_s.strip

  if (photo == "Not found" || photo.nil? || photo.empty?) && url_cell.include?("instagram.com")
    username = extract_username(url_cell)
    puts "↻ Retrying #{username}..."
    res = fetch_ig_avatar(username)

    case res[:status]
    when :ok
      row_vals[photo_idx] = res[:url]
      puts "✅ Found: #{username} → #{res[:url]}"
    when :private
      row_vals[photo_idx] = res[:url]  
      #row_vals[photo_idx] = "Private profile"
      puts "🔒 Private: #{username}"
    else
      row_vals[photo_idx] = "Not found"
      puts "❌ Still not found: #{username}"
    end

    jitter_sleep
  end

  row_vals.each_with_index { |v, c| ws.write(r - 1, c, v) }
end

wb.close
puts "Done: #{OUTPUT}"
