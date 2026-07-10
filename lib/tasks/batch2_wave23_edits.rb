def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Shane Bulloch — remove unsupported XL claim, add partner/hometown
  314 => [
    ["Shane Bulloch is a survivalist who appeared on Naked and Afraid in the 2019 episode Naked and Afraid S10E21 \"Feel the Burn\", dropped into Guyana's scorching savannah to battle oppressive heat and relentless insects. He has also competed on Naked and Afraid XL.",
     "Shane Bulloch is a " + cite("https://www.imdb.com/name/nm11032998/", "Chattanooga, Tennessee superfan") + " who appeared on Naked and Afraid in the 2019 episode Naked and Afraid S10E21 \"Feel the Burn\", partnered with fellow superfan Jennifer Taylor in Guyana's scorching savannah amid oppressive heat and relentless insects."]
  ],

  # Shane Lewis — clip-show debut fix
  315 => [
    ["debuting in 2014's \"Naked and Awkward\"",
     "debuting on the " + cite("https://www.imdb.com/title/tt3019270/", "June 2013 series premiere \"The Jungle Curse\"") + " in Costa Rica"]
  ],

  # Shannon Kulpa — Ogden → Eden
  317 => [
    ["based in Ogden, Utah",
     "based in " + cite("https://www.standard.net/entertainment/2017/apr/30/eden-woman-returns-for-second-helping-of-naked-and-afraid/", "Eden, Utah (Ogden Valley)")]
  ],

  # Shaun Harvey — remove wrong "Sibling Survival" and "Brother's Keeper"
  319 => [
    ["appeared on Naked and Afraid in the 2022 episodes \"Brother's Keeper\" and Naked and Afraid S14E4 \"Sibling Survival\" alongside his brother Warrick",
     "appeared on " + cite("https://www.imdb.com/title/tt18671876/", "Naked and Afraid S14E3 \"Fallen Farmer\"") + " in Zambia (his brother Warrick appeared in the following episode)"]
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

# DB rename: Shawn Brestschneider → Shawn Bretschneider
sb = Survivor.find_by(id: 320)
if sb && sb.full_name == "Shawn Brestschneider"
  sb.full_name = "Shawn Bretschneider"; sb.slug = nil; sb.save!
  puts "→ Renamed to '#{sb.full_name}' (slug '#{sb.slug}')"
end
