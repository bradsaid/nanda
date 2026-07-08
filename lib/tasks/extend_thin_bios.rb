# Extends survivor bios shorter than 300 chars with factual sentences derived
# from the appearance record. Idempotent via an HTML sentinel comment.
SENTINEL = "<!-- extd:v1 -->".freeze

def article(word)
  %w[a e i o u].include?(word[0]&.downcase) ? "an" : "a"
end

def linkify_ep(ep)
  return nil unless ep
  title = ep.title.presence || "Episode #{ep.number_in_season}"
  series = ep.season&.series&.name
  season = ep.season&.number
  label = "#{series} S#{season}E#{ep.number_in_season} \"#{title}\""
  %Q(<a href="/episodes/#{ep.id}">#{label}</a>)
end

def linkify_season(season)
  return nil unless season
  label = "#{season.series&.name} Season #{season.number}"
  %Q(<a href="/seasons/#{season.id}">#{label}</a>)
end

def linkify_country(country)
  return country if country.blank?
  %Q(<a href="/episodes/by_country/#{country.gsub(' ', '%20')}">#{country}</a>)
end

def format_psr(v)
  return nil unless v
  (v % 1).zero? ? v.to_i.to_s : format("%.1f", v)
end

def summarize(survivor)
  name  = survivor.full_name.to_s
  first = name.split.first
  apps  = survivor.appearances.includes(episode: { season: :series, location: nil }).to_a
  eps   = apps.map(&:episode).compact
  seasons = eps.map(&:season).compact.uniq
  countries = eps.map { |e| e.location&.country }.compact.uniq
  psrs = apps.map(&:ending_psr).compact
  starts = apps.map(&:starting_psr).compact
  best_psr = psrs.max
  start_psr = starts.first
  days_arr = apps.map(&:days_lasted).compact
  total_days = days_arr.sum
  results = apps.map(&:result).compact
  completions = results.count { |r| r.match?(/complete|success/i) }
  taps = results.count { |r| r.match?(/tap|medical|evac|out/i) }
  earliest = eps.map(&:air_date).compact.min
  latest = eps.map(&:air_date).compact.max
  # Partners on paired episodes
  partner_names = apps.flat_map { |a|
    a.episode ? a.episode.appearances.reject { |b| b.survivor_id == survivor.id }.map { |b| b.survivor&.full_name }.compact : []
  }.uniq.first(3)
  brought = survivor.appearance_items.where(source: :brought).joins(:item).group("items.name").count
  top_brought = brought.max_by { |_, c| c }&.first if brought.any?

  {
    name: name, first: first, apps: apps, eps: eps, seasons: seasons,
    countries: countries, best_psr: best_psr, start_psr: start_psr, total_days: total_days,
    completions: completions, taps: taps, results_count: results.size,
    earliest: earliest, latest: latest, partners: partner_names, top_brought: top_brought
  }
end

# Assembles 1–3 factual sentences that add information not already in the
# existing bio. Rotates sentence patterns by ID so the corpus doesn't feel
# formulaic.
def compose_extension(survivor, ctx)
  existing = survivor.bio.to_s.downcase
  parts = []

  # Seasons the bio doesn't already reference
  named_seasons = ctx[:seasons].reject { |s|
    existing.include?("season #{s.number}".downcase) &&
      existing.include?(s.series&.name.to_s.downcase)
  }
  if ctx[:seasons].size >= 2
    labels = ctx[:seasons].first(4).map { |s| linkify_season(s) }
    parts << "#{ctx[:first]} has appeared across #{labels.to_sentence}."
  elsif ctx[:seasons].size == 1 && !existing.include?("season")
    parts << "The appearance came in #{linkify_season(ctx[:seasons].first)}."
  end

  # Location / country
  fresh_countries = ctx[:countries].reject { |c| existing.include?(c.to_s.downcase) }
  if fresh_countries.any?
    linked = fresh_countries.first(3).map { |c| linkify_country(c) }
    if fresh_countries.size == 1
      parts << "The challenge was filmed in #{linked.first}."
    else
      parts << "Locations included #{linked.to_sentence}."
    end
  end

  # PSR
  if ctx[:best_psr] && !existing.match?(/psr|primitive survival rating/i)
    psr_str = format_psr(ctx[:best_psr])
    if ctx[:apps].size == 1
      parts << "#{ctx[:first]} finished the challenge with a PSR of #{psr_str}."
    else
      parts << "Their highest recorded PSR across the show sits at #{psr_str}."
    end
  end

  # Days
  if ctx[:total_days] > 0 && !existing.match?(/\d+\s*days?/i)
    if ctx[:apps].size == 1
      parts << "#{ctx[:first]} logged #{ctx[:total_days]} days in the wild on that run."
    else
      parts << "Across every appearance combined, #{ctx[:first]} has logged #{ctx[:total_days]} days on-camera in the wild."
    end
  end

  # Partners for a single-appearance debut
  if ctx[:apps].size == 1 && ctx[:partners].any? && !existing.include?(ctx[:partners].first.to_s.downcase)
    partner = ctx[:partners].first
    parts << "The partner on that challenge was #{partner}."
  end

  # Most-brought item. Skip placeholder items whose name is literally "?"
  # (an unknown-item record) — reads as "brought a ?." nonsense in prose.
  if ctx[:top_brought] && ctx[:top_brought].to_s.strip != "?" &&
     !existing.include?(ctx[:top_brought].to_s.downcase)
    item = ctx[:top_brought]
    parts << "The item they brought into the challenge was #{article(item)} #{item.downcase}."
  end

  # Debut phrasing when the bio doesn't already establish the debut year
  if ctx[:earliest] && !existing.match?(/debut/i) && !existing.include?(ctx[:earliest].year.to_s)
    parts << "#{ctx[:first]}'s Naked and Afraid debut aired in #{ctx[:earliest].year}."
  end

  # Rotate order deterministically per survivor id to avoid a uniform pattern
  offset = survivor.id % [parts.size, 1].max
  parts.rotate(offset).first(3).join(" ")
end

def compose_full_new_bio(survivor, ctx)
  first = ctx[:first]
  name = ctx[:name]
  sentences = []
  if ctx[:apps].size == 1
    ep = ctx[:eps].first
    ep_link = linkify_ep(ep) if ep
    country = ep&.location&.country
    country_link = country ? linkify_country(country) : nil
    year = ep&.air_date&.year
    sentences << "#{name} is a Naked and Afraid survivalist who appeared in #{ep_link}#{country_link ? ", filmed in #{country_link}" : ""}#{year ? " in #{year}" : ""}."
    if ctx[:partners].any?
      sentences << "The partner on that challenge was #{ctx[:partners].first}."
    end
    if ctx[:best_psr]
      sentences << "The run closed with a final PSR of #{format_psr(ctx[:best_psr])}#{ctx[:total_days] > 0 ? " over #{ctx[:total_days]} days on the ground" : ""}."
    elsif ctx[:total_days] > 0
      sentences << "The run lasted #{ctx[:total_days]} days on the ground."
    end
  else
    season_labels = ctx[:seasons].first(4).map { |s| linkify_season(s) }
    sentences << "#{name} is a Naked and Afraid survivalist who has appeared across #{season_labels.to_sentence}."
    if ctx[:countries].any?
      linked = ctx[:countries].first(4).map { |c| linkify_country(c) }
      sentences << "Filming locations across the run include #{linked.to_sentence}."
    end
    if ctx[:best_psr]
      sentences << "Their highest recorded PSR is #{format_psr(ctx[:best_psr])}, with a combined #{ctx[:total_days]} days logged in the wild across every appearance." if ctx[:total_days] > 0
      sentences << "Their highest recorded PSR is #{format_psr(ctx[:best_psr])}." if ctx[:total_days] == 0
    elsif ctx[:total_days] > 0
      sentences << "They have logged a combined #{ctx[:total_days]} days on the show."
    end
  end
  sentences.compact.join(" ")
end

processed = 0
skipped_recent = 0
Survivor.where.not(bio: [nil, "", ""]).where("length(bio) < 300").find_each do |s|
  if s.bio.to_s.include?(SENTINEL)
    skipped_recent += 1
    next
  end
  ctx = summarize(s)
  extension = compose_extension(s, ctx)
  next if extension.blank?
  s.update!(bio: "#{s.bio.strip}\n\n#{extension}\n#{SENTINEL}")
  processed += 1
  puts "  ✓ #{s.full_name} — now #{s.bio.length} chars"
end

new_bios = 0
Survivor.where(bio: [nil, ""]).find_each do |s|
  ctx = summarize(s)
  next if ctx[:apps].empty?
  new_bio = compose_full_new_bio(s, ctx)
  next if new_bio.blank?
  s.update!(bio: "#{new_bio}\n#{SENTINEL}")
  new_bios += 1
  puts "  ★ (new) #{s.full_name} — #{s.bio.length} chars"
end

puts ""
puts "Extended #{processed} thin bios (skipped #{skipped_recent} already-extended)"
puts "Wrote #{new_bios} brand-new bios from empty"
