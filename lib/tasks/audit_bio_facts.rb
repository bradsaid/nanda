# Audit each survivor bio for factual references that can be cross-checked
# against the DB. Report mismatches: episodes/seasons/countries the bio claims
# but that don't match any of the survivor's appearances.

# Known countries in the DB
db_countries = Location.pluck(:country).uniq.compact.reject(&:empty?)
# Also add common informal names / regional references that shouldn't be flagged
country_aliases = {
  "USA" => "United States", "America" => "United States",
  "US" => "United States", "U.S." => "United States",
  "UK" => "United Kingdom", "Britain" => "United Kingdom",
  "Congo" => "Democratic Republic of the Congo"
}
# Regional references we should NOT flag (they're not countries)
regional_hints = %w[
  Amazon Sahara Kalahari Sonoran Chihuahuan Yucatan Yucatán
  Everglades Andes Himalayas Patagonia Outback Andros
  Atchafalaya Rockies Limpopo Selati Jalapao Jalapão
  Chocoyero-El Chaco Rupununi Africa Asia Europe Caribbean
  Americas Bolivia Amazon Africa
]

report = { episode_mismatch: [], season_mismatch: [], country_mismatch: [], title_mismatch: [] }

Survivor.all.each do |s|
  # Strip HTML — we compare plain text
  bio = ActionView::Base.full_sanitizer.sanitize(s.bio.to_s).gsub(/\s+/, " ").strip
  next if bio.blank?

  apps = s.appearances.includes(episode: [{ season: :series }, :location]).to_a
  actual_eps = apps.map(&:episode).compact
  actual_countries = actual_eps.map { |e| e.location&.country }.compact.uniq
  actual_series_seasons = actual_eps.map { |e| [e.season&.series&.name, e.season&.number] }.uniq

  # ------------------------------------------------------------
  # 1) EPISODE references: "S{N}E{M}" pattern
  # ------------------------------------------------------------
  bio.scan(/S(\d+)E(\d+)/i).uniq.each do |(sn, en)|
    sn, en = sn.to_i, en.to_i
    # Does the survivor have an appearance in ANY series' S{sn}E{en}?
    match = actual_eps.any? { |e| e.season&.number == sn && e.number_in_season == en }
    unless match
      # Determine which series is most likely being referenced by finding the nearest series-name mention
      report[:episode_mismatch] << { s: s, ref: "S#{sn}E#{en}",
                                    actual: actual_eps.map { |e| "S#{e.season&.number}E#{e.number_in_season}" }.uniq.first(6) }
    end
  end

  # ------------------------------------------------------------
  # 2) SEASON references: "Season N" of a series
  # ------------------------------------------------------------
  # Find all "Season N" patterns and check which series is referenced nearby
  bio.scan(/(Naked and Afraid(?:[:.] [A-Z][a-zA-Z ]+?)?)['s]* (?:Season |season |S)(\d+)\b/).each do |(series_ref, num)|
    num = num.to_i
    # Normalize series name
    series_name = series_ref.strip.sub(/'s$/, "")
    match = actual_series_seasons.any? { |sn, snum| sn == series_name && snum == num }
    # Also accept a permissive match where any series has that season number
    permissive = actual_series_seasons.any? { |_, snum| snum == num }
    unless match || permissive
      report[:season_mismatch] << { s: s, ref: "#{series_name} S#{num}",
                                   actual: actual_series_seasons.map { |sn, snum| "#{sn} S#{snum}" }.uniq }
    end
  end

  # ------------------------------------------------------------
  # 3) COUNTRY references: check countries mentioned in bio vs actual episode countries
  # ------------------------------------------------------------
  # Look for each known country's name as a whole word
  mentioned_countries = []
  db_countries.each do |c|
    if bio =~ /\b#{Regexp.escape(c)}\b/i
      mentioned_countries << c
    end
  end
  # Common informal → canonical
  country_aliases.each do |informal, canonical|
    if bio =~ /\b#{Regexp.escape(informal)}\b/i && !mentioned_countries.include?(canonical)
      mentioned_countries << canonical
    end
  end
  # Flag any country mentioned that isn't in the survivor's actual appearance list
  mentioned_countries.uniq.each do |mc|
    unless actual_countries.include?(mc)
      report[:country_mismatch] << { s: s, mentioned: mc, actual: actual_countries }
    end
  end

  # ------------------------------------------------------------
  # 4) EPISODE TITLES in quotes: verify the survivor was in an ep with that title
  # ------------------------------------------------------------
  # Extract "quoted phrases" that look like episode titles (Title Case, 2+ words)
  bio.scan(/"([A-Z][A-Za-z0-9'&,! ?:-]{2,50})"/).each do |(quoted)|
    # Skip nicknames (single word), brand names, quotes with numbers, etc.
    next if quoted.split.size < 2
    next if quoted.split.all? { |w| w.length < 3 }
    # Look for match in the survivor's actual episodes (case-insensitive, tolerate small punctuation)
    match = actual_eps.any? do |e|
      title = e.title.to_s
      title.downcase.gsub(/[^a-z0-9 ]/, "") == quoted.downcase.gsub(/[^a-z0-9 ]/, "") ||
        title.downcase.include?(quoted.downcase) ||
        quoted.downcase.include?(title.downcase)
    end
    unless match
      # Check if the quoted phrase matches any known N&A episode title in the DB (some quotes may
      # be about episodes the survivor DIDN'T appear in — flag those separately)
      exists_in_db = Episode.where("LOWER(title) = ?", quoted.downcase).exists?
      report[:title_mismatch] << { s: s, quoted: quoted,
                                  exists_in_db: exists_in_db,
                                  actual: actual_eps.map(&:title).uniq.first(6) }
    end
  end
end

# Print each report section
[:episode_mismatch, :season_mismatch, :country_mismatch, :title_mismatch].each do |k|
  puts "=" * 60
  puts "#{k.to_s.upcase} (#{report[k].size})"
  puts "=" * 60
  report[k].each do |m|
    if k == :episode_mismatch
      puts "  #{m[:s].full_name} (id=#{m[:s].id}): bio says #{m[:ref]} but survivor's actual eps are #{m[:actual].join(', ')}"
    elsif k == :season_mismatch
      puts "  #{m[:s].full_name} (id=#{m[:s].id}): bio says #{m[:ref]} but survivor's actual seasons are #{m[:actual].join(', ')}"
    elsif k == :country_mismatch
      puts "  #{m[:s].full_name} (id=#{m[:s].id}): bio mentions '#{m[:mentioned]}' but actual countries are #{m[:actual].join(', ')}"
    elsif k == :title_mismatch
      note = m[:exists_in_db] ? "(exists in DB — wrong survivor?)" : "(not in DB)"
      puts "  #{m[:s].full_name} (id=#{m[:s].id}): bio quotes \"#{m[:quoted]}\" #{note} — actual eps: #{m[:actual].join(', ')}"
    end
  end
  puts
end
