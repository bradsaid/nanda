def bucket(path)
  case path
  when "/" then "home"
  when %r{\A/survivors/[^/]+} then "survivor page"
  when %r{\A/survivors\z}, %r{\A/survivors\?} then "survivors index"
  when %r{\A/items/[^/]+} then "item page"
  when %r{\A/items\z}, %r{\A/items\?} then "items index"
  when %r{\A/episodes/by_country} then "country page"
  when %r{\A/episodes/\d} then "episode page"
  when %r{\A/episodes\z}, %r{\A/episodes\?} then "episodes index"
  when %r{\A/seasons} then "seasons"
  when %r{\A/locations} then "locations"
  when %r{\A/(podcasts|about|contact|privacy)} then "static"
  when %r{page_view_ping|rails/active_storage|assets|favicon} then "_asset_"
  else "other"
  end
end

human_ua = "user_agent NOT ILIKE '%bot%' AND user_agent NOT ILIKE '%spider%' AND user_agent NOT ILIKE '%crawl%'"
[["All time", PageView.where(human_ua)],
 ["Last 30 days", PageView.where(human_ua).where(created_at: 30.days.ago..)],
 ["Last 7 days", PageView.where(human_ua).where(created_at: 7.days.ago..)]].each do |label, rel|
  counts = Hash.new(0)
  rel.pluck(:path).each { |p| b = bucket(p); counts[b] += 1 unless b == "_asset_" }
  total = counts.values.sum
  puts "=== #{label} (#{total} human views) ==="
  counts.sort_by { |_, c| -c }.first(10).each do |b, c|
    pct = (100.0 * c / total).round(1)
    puts "  #{b.ljust(20)} #{c.to_s.rjust(6)}  #{pct}%"
  end
  puts
end
