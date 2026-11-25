# Scan all survivor bios for broken links.
# Internal links: verify referenced episodes/survivors exist in DB.
# External links: collected for separate HTTP check.

require "uri"

internal_broken = []
external_urls = {}  # url => [survivor_names]

Survivor.all.each do |s|
  bio = s.bio.to_s
  next if bio.empty?

  # Extract href="..." from anchor tags
  bio.scan(/href="([^"]+)"/).each do |(href)|
    href = href.strip
    next if href.empty?

    if href.start_with?("/episodes/")
      # /episodes/<slug or N>, /episodes/by_country/<slug or old Name>, /episodes
      if href.start_with?("/episodes/by_country/")
        country = CGI.unescape(href.sub("/episodes/by_country/", ""))
        unless NameSlugs.resolve(:country, country)
          internal_broken << { survivor: s.full_name, id: s.id, href: href, reason: "no episodes for country '#{country}'" }
        end
      elsif href =~ %r{\A/episodes/([^/?#]+)\z}
        ref = $1
        unless (Episode.friendly.find(ref) rescue nil)
          internal_broken << { survivor: s.full_name, id: s.id, href: href, reason: "episode '#{ref}' missing" }
        end
      end
    elsif href.start_with?("/survivors/")
      slug = href.sub("/survivors/", "")
      found = (Survivor.friendly.find(slug) rescue nil)
      unless found
        internal_broken << { survivor: s.full_name, id: s.id, href: href, reason: "survivor slug '#{slug}' missing" }
      end
    elsif href.start_with?("/seasons")
      # /seasons or /seasons/N
      if href =~ %r{\A/seasons/(\d+)\z}
        sid = $1.to_i
        unless Season.exists?(sid)
          internal_broken << { survivor: s.full_name, id: s.id, href: href, reason: "season id #{sid} missing" }
        end
      end
      # /seasons alone is a static index page, skip
    elsif href.start_with?("http://") || href.start_with?("https://")
      external_urls[href] ||= []
      external_urls[href] << s.full_name
    end
  end
end

puts "=== INTERNAL BROKEN (#{internal_broken.count}) ==="
internal_broken.each do |b|
  puts "  #{b[:survivor]} (id=#{b[:id]}): #{b[:href]} — #{b[:reason]}"
end

puts
puts "=== EXTERNAL URLS TO CHECK (#{external_urls.size} unique) ==="
File.open("/tmp/external_urls.txt", "w:UTF-8") do |f|
  external_urls.each { |url, survs| f.puts "#{url}\t#{survs.join(', ')}" }
end
puts "Wrote /tmp/external_urls.txt"
