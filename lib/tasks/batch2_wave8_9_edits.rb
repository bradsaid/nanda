# Batch 2, waves 8–9 (survivors 97–126) verification edits.
def normalize_whitespace(s)
  s.gsub(/[ \t]{2,}/, " ").gsub(/\s+([.,!?;:])/, '\1').strip
end
def cite(url, phrase)
  %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>)
end

EDITS = {
  # Wave 8 — Daren Jackson episode misattribution
  89 => [
    ["season 11 episode Naked and Afraid S9E9 \"Loaded for Bear\"",
     "season 11 episode " + cite("https://www.imdb.com/title/tt12211994/", "Naked and Afraid S11E3 \"Bahama Drama\"")]
  ],

  # Dragonsky Curtis
  399 => [
    ["Her work can be found at Summits and Spoons.",
     "Her work can be found at " + cite("https://linktr.ee/I_Am_Dragonsky", "The Dragonsky Escapades") + "."],
    ["Her debut articles and memoir have helped spark",
     "Her debut articles and " + cite("https://travelnoire.com/author-shilletha-curtis-new-book", "memoir \"Pack Light: A Journey to Find Myself\"") + " have helped spark"]
  ],

  # Wave 9 — Erin Heim partner name
  112 => [
    ["professional boxer Martin Sims",
     "professional boxer " + cite("https://www.youtube.com/watch?v=rN_zqVCze0A", "Marlin Sims")]
  ],

  # Ernie Hinojos
  113 => [
    ["30-year U.S. Army veteran and former Little Rock and Bryant, Arkansas police officer who became a longtime fan of Naked and Afraid before joining the show himself. He appeared in 2025 paired with Amanda Wilson for a 14-day challenge in Mexico's Yucatan Peninsula on \"Alone and Terrified\".",
     "combined 30-year " + cite("https://www.bentoncourier.com/entertainment/saline-county-resident-to-appear-on-upcoming-episode-of-naked-and-afraid/article_1d8cd148-f947-11ef-b1af-8728547c3b62.html", "U.S. Army and Arkansas National Guard veteran") + " and former Little Rock and Bryant, Arkansas police officer who became a longtime fan of Naked and Afraid before joining the show himself. He appeared in 2025 paired with Amanda \"Mandy\" Wilson for a 14-day Yucatan Peninsula fan challenge on \"Couch to Cave\" (S18E2)."]
  ],

  # Fairland Ferguson
  115 => [
    ["survived a 70-foot cliff fall that broke 46 bones",
     "survived a " + cite("https://roanokeequestrian.com/", "68-foot cliff fall at Smith Mountain Lake, Virginia") + " that broke 46 bones"]
  ],

  # Emily Caselman
  110 => [
    ["She was paired with a cautious archaeologist in the Texas desert on",
     "As a National Park Service archaeologist she was paired with impulsive adventurer " + cite("https://www.imdb.com/title/tt14356778/", "Lincoln Samuelson") + " in the Texas desert on"]
  ],

  # Dylan Williams — full bio replace since name is wrong
  103 => [
    ["Dylan Williams is a Naked and Afraid survivalist who appeared in Naked and Afraid S10E8 \"Bite Club\", filmed in Mozambique in 2019.",
     "Dylan McWilliams, known for having survived a rattlesnake bite, a shark attack, and a bear attack in a span of years, is a " + cite("https://www.imdb.com/title/tt10146196/", "Naked and Afraid survivalist who appeared in S10E8 \"Bite Club\"") + ", filmed in Mozambique in 2019."]
  ]
}

edited = 0
missed = []
EDITS.each do |sid, replacements|
  s = Survivor.find_by(id: sid)
  next unless s
  before = s.bio.to_s
  after = before.dup
  applied = false
  replacements.each do |find, replace|
    if after.include?(find)
      after = after.sub(find, replace)
      applied = true
    end
  end
  if applied
    s.update!(bio: normalize_whitespace(after))
    edited += 1
    puts "  E #{s.full_name}"
  else
    missed << "#{s.full_name} (id=#{sid})"
  end
end
puts "→ Applied #{edited} bio edits"
missed.each { |m| puts "  ! #{m}" } if missed.any?

# DB rename: Dylan Williams → Dylan McWilliams
d = Survivor.find_by(id: 103)
if d && d.full_name == "Dylan Williams"
  d.full_name = "Dylan McWilliams"
  d.slug = nil
  d.save!
  puts "→ Renamed 'Dylan Williams' → '#{d.full_name}' (slug '#{d.slug}')"
end
