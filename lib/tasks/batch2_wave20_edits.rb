def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Nathan Martinez — CRITICAL: remove wrongly-attributed transgender/non-binary claim
  267 => [
    [", where he was featured as the show's first transgender, non-binary survivalist",
     ""]
  ],

  # Nicole Pisani — 2019 → 2020
  433 => [
    ["which she opened in 2019",
     "which she " + cite("https://www.b2bthegrandstrand.com/stories/nikkicoles-hair-design-and-head-spa-building-a-people-first-salon-that-puts-experience-balance,39336", "opened in 2020")]
  ],

  # Noah Mattes — Matt Wright → Max Djenohan
  273 => [
    ["with legend Matt Wright",
     "with legend " + cite("https://www.imdb.com/title/tt19382466/", "Max Djenohan")]
  ],

  # Pearson Caldwell — major rewrite (Zambia/Clash → Thailand/Like Subscribe Survive)
  402 => [
    ["Pearson Caldwell is the outdoorsman behind the Country Tactical (CoTac) social channels, which focus on hunting and tactical content, and he runs the outdoor brand Hardship Supply. He competed in Naked and Afraid Season 19, where in the episode \"Clash of the Survivalists\" a laid-back hunter and an opinionated adventure guide attempted a 21-day challenge in Zambia.",
     "Pearson Caldwell is an East Texas outdoorsman behind " + cite("https://www.instagram.com/countrytactical/", "Country Tactical (CoTac)") + " (~1M Instagram followers) who went viral in 2023 building a log cabin by hand in Van Zandt County, and he runs the outdoor brand Hardship Supply. He competed on " + cite("https://www.imdb.com/news/ni65719243/", "Naked and Afraid S19E3 \"Like, Subscribe and Survive\"") + " — a 14-day challenge in Thailand featuring five social-media influencers."]
  ]
}

edited = 0; missed = []
EDITS.each do |sid, replacements|
  s = Survivor.find_by(id: sid); next unless s
  before = s.bio.to_s; after = before.dup; applied = false
  replacements.each do |find, replace|
    if after.include?(find); after = after.sub(find, replace); applied = true; end
  end
  if applied; s.update!(bio: normalize(after)); edited += 1; puts "  E #{s.full_name}"
  else; missed << "#{s.full_name} (id=#{sid})"; end
end
puts "→ #{edited} edits"
missed.each { |m| puts "  ! #{m}" }

# DB rename: Paolo Digiralomo → Paolo Di Girolamo
pd = Survivor.find_by(id: 275)
if pd && pd.full_name == "Paolo Digiralomo"
  pd.full_name = "Paolo Di Girolamo"; pd.slug = nil; pd.save!
  puts "→ Renamed to '#{pd.full_name}' (slug '#{pd.slug}')"
end

# DB fix: S18E10 title typo
ep = Episode.find_by(title: "Mayan Blood Sacrafice")
if ep
  ep.update!(title: "Mayan Blood Sacrifice")
  puts "→ Fixed episode title: '#{ep.title}'"
end
