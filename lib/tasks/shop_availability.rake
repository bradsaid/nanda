require "net/http"
require "uri"

# Checks every Amazon listing in config/shop_products.yml and reports which are unavailable.
#
#   bin/rake shop:availability            # report only
#   bin/rake shop:availability WRITE=1    # also update `availability:` in the YAML
#
# Amazon marks a listing with id="outOfStock" when it is "Currently unavailable" and with
# id="add-to-cart-button" when it can be bought. Anything else (captcha, odd page) is reported
# as unknown and left alone. A product marked `availability: discontinued` by hand is never
# changed by this task. The home page hides every product that has an availability value.
#
# This is a snapshot: stock changes, so re-run it before relying on it.
namespace :shop do
  desc "Check Amazon listings for out-of-stock products (WRITE=1 to update the catalog file)"
  task :availability do
    path   = File.expand_path("../../config/shop_products.yml", __dir__)
    text   = File.read(path)
    blocks = text.split(/^(?=- item:)/)             # [header, block, block, ...]
    delay  = Float(ENV.fetch("DELAY", "1.5"))
    ua     = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    fetch = lambda do |url|
      uri = URI(url)
      3.times do
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
          http.get(uri.request_uri, "User-Agent" => ua, "Accept-Language" => "en-US,en;q=0.9")
        end
        return res.body.to_s.force_encoding("UTF-8").scrub if res.is_a?(Net::HTTPSuccess)
        if res.is_a?(Net::HTTPRedirection)
          uri = URI.join(uri, res["location"])
        else
          return nil
        end
      end
      nil
    end

    status_of = lambda do |html|
      return :unknown if html.nil?
      return :captcha if html.include?("api-services-support@amazon.com") || html.include?("Enter the characters you see below")
      return :out_of_stock if html.include?('id="outOfStock"')
      return :available if html.include?('id="add-to-cart-button"')
      :unknown
    end

    counts  = Hash.new(0)
    changes = []
    backoff = Integer(ENV.fetch("BACKOFF", "90"))

    blocks.each_with_index do |blk, i|
      next unless blk.start_with?("- item:")
      url = blk[%r{url: (https://www\.amazon\.com/\S+)}, 1]
      next unless url
      name    = blk[/^  product: (.*)$/, 1].to_s[0, 60]
      current = blk[/^  availability: (\w+)/, 1]

      sleep delay
      status = status_of.call(fetch.call(url))
      # Amazon throttles scrapers with a captcha; back off and retry before giving up.
      tries = 0
      while status == :captcha && tries < 3
        tries += 1
        warn "  captcha, waiting #{backoff}s (try #{tries}/3)..."
        sleep backoff
        status = status_of.call(fetch.call(url))
      end
      abort "Amazon keeps serving captchas; stopping so nothing is changed. Try again later." if status == :captcha
      counts[status] += 1

      puts format("%-13s %-14s %s", status, current || "-", name)

      new_value =
        case status
        when :out_of_stock then current == "discontinued" ? "discontinued" : "out_of_stock"
        when :available    then current == "discontinued" ? "discontinued" : nil
        else current
        end
      next if new_value == current

      blk = blk.sub(/^  availability: \w+\n/, "")
      blk = blk.sub(/^(  match: .*\n)/) { "#{$1}  availability: #{new_value}\n" } if new_value
      blocks[i] = blk
      changes << "#{name}: #{current || 'available'} -> #{new_value || 'available'}"
    end

    puts "\n#{counts.map { |k, v| "#{v} #{k}" }.join(', ')}"
    puts changes.empty? ? "No changes." : "Changes:\n  #{changes.join("\n  ")}"

    if ENV["WRITE"] == "1" && changes.any?
      File.write(path, blocks.join)
      puts "Updated #{path}"
    elsif changes.any?
      puts "(report only: re-run with WRITE=1 to update the file)"
    end
  end
end
