# V2: only flag country mentions in CHALLENGE-LOCATION context.

db_countries = Location.pluck(:country).uniq.compact.reject(&:empty?)

# Skip words that are hometown/nationality/geographic-region contexts.
# We only care about "challenge/survived/dropped in <COUNTRY>" mentions.
def looks_like_challenge_location?(bio, country)
  # Find each occurrence of the country name; check 40 chars before it for
  # phrases that suggest a challenge location, not a hometown/heritage.
  bio.to_enum(:scan, /\b#{Regexp.escape(country)}\b/i).map { Regexp.last_match }.any? do |m|
    idx = m.begin(0)
    lead_start = [idx - 60, 0].max
    lead = bio[lead_start...idx].downcase

    # Positive markers: challenge phrasing
    return true if lead =~ /
      \b(?:in|dropped|survived|took\s+on|attempted|completed|day\s+\d+\s+in|
        challenge\s+in|jungle\s+of|desert\s+of|episode\s+in|filmed\s+in|
        savann?ah?\s+of|rainforest\s+of|bush\s+of|wilderness\s+of|
        expedition\s+to|paired.*in|competed\s+in|braved|episode\s+set\s+in|
        set\s+in|shot\s+in|debuted\s+in|returned\s+to|challenge.*in)\b
      [^.]{0,30}\z/xm

    false
  end
end

report = { episode_mismatch: [], country_mismatch: [], title_mismatch: [] }

Survivor.all.each do |s|
  bio = ActionView::Base.full_sanitizer.sanitize(s.bio.to_s).gsub(/\s+/, " ").strip
  next if bio.blank?

  apps = s.appearances.includes(episode: [{ season: :series }, :location]).to_a
  actual_eps = apps.map(&:episode).compact
  actual_countries = actual_eps.map { |e| e.location&.country }.compact.uniq

  # 1) EPISODE references
  bio.scan(/S(\d+)E(\d+)/i).uniq.each do |(sn, en)|
    sn, en = sn.to_i, en.to_i
    match = actual_eps.any? { |e| e.season&.number == sn && e.number_in_season == en }
    unless match
      report[:episode_mismatch] << {
        s: s, ref: "S#{sn}E#{en}",
        actual: actual_eps.map { |e| "S#{e.season&.number}E#{e.number_in_season}" }.uniq.first(6)
      }
    end
  end

  # 2) COUNTRY mentions in challenge context
  db_countries.each do |c|
    next unless bio =~ /\b#{Regexp.escape(c)}\b/i
    next if actual_countries.include?(c)
    next unless looks_like_challenge_location?(bio, c)
    report[:country_mismatch] << { s: s, mentioned: c, actual: actual_countries }
  end

  # 3) QUOTED EPISODE TITLES that don't match survivor's actual eps
  bio.scan(/"([A-Z][A-Za-z0-9'&,! ?:-]{2,60})"/).each do |(quoted)|
    next if quoted.split.size < 2
    match = actual_eps.any? do |e|
      title = e.title.to_s
      norm_title = title.downcase.gsub(/[^a-z0-9 ]/, "")
      norm_quoted = quoted.downcase.gsub(/[^a-z0-9 ]/, "")
      norm_title == norm_quoted || norm_title.include?(norm_quoted) || norm_quoted.include?(norm_title)
    end
    unless match
      exists_in_db = Episode.where("LOWER(title) = ?", quoted.downcase).exists?
      # Skip common non-episode quoted phrases: mono-word nicknames should already be filtered
      # by the 2+ words rule. Also skip trailing commas (nicknames like "Tarzan,")
      next if quoted.end_with?(",")
      report[:title_mismatch] << {
        s: s, quoted: quoted, exists_in_db: exists_in_db,
        actual: actual_eps.map(&:title).uniq.first(6)
      }
    end
  end
end

puts "=" * 60
puts "EPISODE_MISMATCH (#{report[:episode_mismatch].size})"
puts "=" * 60
report[:episode_mismatch].each do |m|
  puts "  #{m[:s].full_name} (id=#{m[:s].id}): bio says #{m[:ref]}; DB has #{m[:actual].join(', ')}"
end

puts
puts "=" * 60
puts "COUNTRY_MISMATCH (#{report[:country_mismatch].size})"
puts "=" * 60
report[:country_mismatch].each do |m|
  puts "  #{m[:s].full_name} (id=#{m[:s].id}): bio's challenge context mentions '#{m[:mentioned]}'; DB shows #{m[:actual].join(', ')}"
end

puts
puts "=" * 60
puts "TITLE_MISMATCH (#{report[:title_mismatch].size})"
puts "=" * 60
report[:title_mismatch].each do |m|
  note = m[:exists_in_db] ? "(exists in DB — wrong survivor or missing appearance)" : "(not in DB)"
  puts "  #{m[:s].full_name} (id=#{m[:s].id}): bio quotes \"#{m[:quoted]}\" #{note}"
  puts "    DB eps: #{m[:actual].join(', ')}"
end
