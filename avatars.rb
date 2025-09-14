# frozen_string_literal: true
# Usage: ruby avatars_roo.rb /path/to/avatars.xlsx
require "roo"
require "write_xlsx"
require "net/http"
require "json"
require "uri"

INPUT  = ARGV[0] || File.expand_path("~/Desktop/avatars.xlsx")
OUTPUT = File.expand_path("~/Desktop/avatars_with_photos.xlsx")

def extract_username(instagram_url)
  u = URI(instagram_url) rescue nil
  return nil unless u && u.host&.include?("instagram.com")
  u.path.split("/").reject(&:empty?).first
end

def fetch_ig_avatar(username)
  return nil if username.nil? || username.empty?
  uri = URI("https://i.instagram.com/api/v1/users/web_profile_info/?username=#{username}")
  req = Net::HTTP::Get.new(uri)
  req["User-Agent"] = "Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0 Mobile Safari/537.36"
  req["X-IG-App-ID"] = "936619743392459" # required by this web endpoint
  puts "Requesting #{username}..."
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
    res = http.request(req)
    return nil unless res.is_a?(Net::HTTPSuccess)
    data = JSON.parse(res.body) rescue nil
    user = data && data.dig("data", "user")
    user && (user["profile_pic_url_hd"] || user["profile_pic_url"])
  end
rescue
  nil
end

xlsx = Roo::Excelx.new(INPUT)
sheet_name = xlsx.sheets.first
xlsx.default_sheet = sheet_name

# headers in row 1
headers = xlsx.row(1).map { |h| h.to_s.strip }
insta_idx = headers.index("Instagram")
photo_idx = headers.index("Photo")
raise "Column 'Instagram' not found" unless insta_idx
raise "Column 'Photo' not found"     unless photo_idx

# create output workbook
wb  = WriteXLSX.new(OUTPUT)
ws  = wb.add_worksheet(sheet_name || "Sheet1")

# write headers
headers.each_with_index { |h, c| ws.write(0, c, h) }

last_row = xlsx.last_row
(2..last_row).each do |r|
  row_vals = xlsx.row(r) # array sized to last column with nils for blanks
  row_vals = row_vals.dup

  url = row_vals[insta_idx].to_s.strip
  avatar = nil
  if url.include?("instagram.com")
    username = extract_username(url)
    puts "Fetching avatar for #{username}..."
    avatar = fetch_ig_avatar(username) || "Not found"
    sleep 0.8
  end

  row_vals[photo_idx] = avatar if url && !url.empty?
  row_vals.each_with_index { |v, c| ws.write(r - 1, c, v) }
end

wb.close
puts "Done: #{OUTPUT}"
