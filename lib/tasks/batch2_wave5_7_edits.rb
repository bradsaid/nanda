# Batch 2, waves 5–7 (survivors 51–96) verification edits.
# Applies fact corrections + inline source citations.
# Idempotent per-string-match.

def normalize_whitespace(s)
  s.gsub(/[ \t]{2,}/, " ").gsub(/\s+([.,!?;:])/, '\1').strip
end

def cite(url, phrase)
  %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>)
end

EDITS = {
  # ─── Wave 5 ───
  # Blair Braverman (46) — hyenas→spitting cobras, drop "training" framing
  46 => [
    ["South Africa, where she survived alongside elephants and hyenas just weeks before beginning Iditarod training.",
     "the South Africa-Botswana border, where she survived alongside elephants and " + cite("https://www.outsideonline.com/culture/books-media/naked-and-afraid-real-blair-braverman/", "spitting cobras") + "; the episode aired days after she finished her first Iditarod."]
  ],

  # Bree Walker (51) — Cornejal → Cangrejal
  51 => [
    ["Cornejal River", cite("https://visitatlantida.com/en/tag/naked-and-afraid-in-honduras/", "Cangrejal River")]
  ],

  # Brittany Wallace (54) — Idaho → Indiana; partner → 3-person team
  54 => [
    ["Brittany Wallace is an Idaho-based mother",
     "Brittany Wallace is an " + cite("https://www.imdb.com/name/nm12870320/", "Indiana-based mother")],
    ["The partner on that challenge was Aosha Wells.",
     "It was a " + cite("https://thetvdb.com/series/naked-and-afraid/episodes/8611730", "three-person team") + ": Brittany, Aosha Wells, and Tanner Barclay."]
  ],

  # ─── Wave 6 ───
  # Cassie DePecol (63) — Guinness detail + co-host correction
  63 => [
    ["first woman on record to travel to every sovereign country in the world, a feat that earned her two Guinness World Records",
     "first documented woman to visit every sovereign country in the world (a disputed claim); she holds " + cite("https://en.wikipedia.org/wiki/Cassandra_De_Pecol", "two Guinness records") + " for the fastest time overall and the fastest time by a woman"],
    ["She now hosts the Against the Odds podcast",
     "She now " + cite("https://podcasts.apple.com/us/podcast/against-the-odds/id1553335461", "co-hosts Wondery's Against the Odds podcast with Mike Corey")]
  ],

  # Charlie Frattini (70) — Ecuador is XL S3, not S6E1
  70 => [
    ["including episodes Naked and Afraid XL S5E6 \"No Hand-Outs\" and Naked and Afraid XL S6E1 \"Valley of the Banished\", taking on a 40-day challenge in Ecuador.",
     "including " + cite("https://thecinemaholic.com/naked-and-afraid-xl-filming-locations/", "Naked and Afraid XL Season 3 in Ecuador (2017)") + " and Naked and Afraid XL S5E6 \"No Hand-Outs\" in the Philippines (2019)."]
  ],

  # Cheeny Plante (71) — Maine Guide status correction
  71 => [
    ["She now works as a wilderness guide and is training to become a certified Maine Guide.",
     "She now works full-time as an interior painter and part-time as a " + cite("https://www.themainewire.com/2025/07/maines-own-cheeny-plante-shows-true-grit-in-naked-and-afraid-last-one-standing-finale/", "Maine Guide and survival instructor") + "."]
  ],

  # ─── Wave 7 ───
  # Clint Jivoin (77) — desert → jungle
  77 => [
    ["taking on a Panamanian desert island",
     "taking on a " + cite("https://tv.apple.com/us/episode/punishment-in-panama/umc.cmc.1xxc1pi3nb6i0m2x11x7a4o94", "Panamanian tropical jungle island")]
  ],

  # Cole Wilks (78) — Michelle → Shell
  78 => [
    ["completing a 21-day challenge in South Africa with partner Michelle Armogida.",
     "completing a 21-day challenge in South Africa with partner Shell (Michelle) Armogida."]
  ],

  # Cory Williams (80) — SMP company/channel + drop unsourced firefighter/EMT/stuntman
  80 => [
    ["is a longtime American YouTube personality who founded the SMP Films channel in 1999 and is based in Oklahoma. A former California Department of Forestry firefighter, certified EMT, and stuntman, he appeared",
     "is a longtime American YouTube personality who " + cite("https://en.wikipedia.org/wiki/Cory_Williams", "founded SMP Films (a production company) in 1999 and launched the SMP Films YouTube channel in 2005") + ". Based in Oklahoma, he appeared"]
  ],

  # Dallas Langston (81) — drop military claim
  81 => [
    ["Dallas Langston is a U.S. military veteran originally from St. George, Utah",
     "Dallas Langston is an entrepreneur originally from St. George, Utah"]
  ],

  # Connie Kohlen (79) — drop "Connie" nickname + NOLS/WMI removal (name rename below)
  79 => [
    ["Corinne \"Connie\" Kohlen is a registered dietitian based in San Luis Obispo, California, whose survival training includes the National Outdoor Leadership School and the Wilderness Medical Institute.",
     "Corinne Kohlen is a " + cite("https://www.calpoly.edu/directory/ckohlen", "registered dietitian based in San Luis Obispo, California") + "."]
  ]
}

edited = 0
missed = []
EDITS.each do |sid, replacements|
  s = Survivor.find_by(id: sid)
  unless s
    missed << "id=#{sid} not found"
    next
  end
  before = s.bio.to_s
  after = before.dup
  applied = false
  replacements.each do |find, replace|
    if after.include?(find)
      after = after.sub(find, replace)
      applied = true
    end
  end
  if applied && after != before
    s.update!(bio: normalize_whitespace(after))
    edited += 1
    puts "  E #{s.full_name}"
  elsif !applied
    missed << "#{s.full_name} (id=#{sid})"
  end
end
puts "→ Applied #{edited} bio edits"
missed.each { |m| puts "  ! miss: #{m}" } if missed.any?
puts ""

# ─── DB-level renames ───
renames = {
  61 => "Cassidy",       # Cass Caddidy → Leonard "Cass" Cassidy (but slug uses just last name pattern)
  79 => "Corinne Kohlen" # Connie Kohlen → Corinne Kohlen
}

renames.each do |sid, new_name|
  s = Survivor.find_by(id: sid)
  next unless s
  # Cass rename is trickier — the actual full name per IMDb is "Leonard 'Cass' Cassidy" but bio uses "Cass Caddidy"
  # For DB consistency, just fix the surname misspelling
  if sid == 61
    s.full_name = "Cass Cassidy" # fix the "Caddidy" typo
  else
    s.full_name = new_name
  end
  s.slug = nil # friendly_id regenerates
  s.save!
  puts "→ Renamed to '#{s.full_name}' (slug '#{s.slug}')"
end
