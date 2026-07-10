File.open("/tmp/wave16.txt", "w:UTF-8") do |f|
  Survivor.order(:full_name).offset(219).limit(15).each_with_index do |s, i|
    idx = (i + 220).to_s.rjust(3)
    full = s.full_name.to_s.dup.force_encoding("UTF-8").scrub
    slug = s.slug.to_s.dup.force_encoding("UTF-8").scrub
    f.puts "=== #{idx}. #{full} (id=#{s.id}, slug=#{slug}) ==="
    bio = ActionView::Base.full_sanitizer.sanitize(s.bio.to_s.dup.force_encoding("UTF-8").scrub).sub(/\s*<!-- extd:v1 -->\s*\z/, "").strip
    f.puts "BIO: #{bio}"
    apps = s.appearances.includes(episode: [{ season: :series }, :location]).to_a
    f.puts "DB (#{apps.size} apps):"
    apps.each do |a|
      ep = a.episode; next unless ep
      series  = ep.season&.series&.name.to_s.dup.force_encoding("UTF-8").scrub
      title   = ep.title.to_s.dup.force_encoding("UTF-8").scrub
      country = ep.location&.country.to_s.dup.force_encoding("UTF-8").scrub
      f.puts "  #{series} S#{ep.season&.number}E#{ep.number_in_season} '#{title}' - #{country} - #{ep.air_date}"
    end
    f.puts ""
  end
end
puts "OK"
