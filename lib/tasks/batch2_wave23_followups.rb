def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Shane Bulloch — HTML-aware
  314 => [
    ["Shane Bulloch is a survivalist who appeared on <a href=\"/seasons\">Naked and Afraid</a> in the 2019 episode <a href=\"/episodes/99\">Naked and Afraid S10E21 \"Feel the Burn\"</a>, dropped into Guyana's scorching savannah to battle oppressive heat and relentless insects. He has also competed on <a href=\"/seasons\">Naked and Afraid XL</a>.",
     "Shane Bulloch is a " + cite("https://www.imdb.com/name/nm11032998/", "Chattanooga, Tennessee superfan") + " who appeared on <a href=\"/episodes/99\">Naked and Afraid S10E21 \"Feel the Burn\"</a> (2019), partnered with fellow superfan Jennifer Taylor in Guyana's scorching savannah amid oppressive heat and relentless insects."]
  ],

  # Shane Lewis — HTML-aware clip-show fix
  315 => [
    ["(debuting in 2014's <em>\"Naked and Awkward\"</em>)",
     "(debuting on the " + cite("https://www.imdb.com/title/tt3019270/", "June 2013 series premiere \"The Jungle Curse\"") + " in Costa Rica)"]
  ],

  # Shaun Harvey — remove wrong episodes
  319 => [
    ["appeared on <a href=\"/seasons\">Naked and Afraid</a> in the 2022 episodes <em>\"Brother's Keeper\"</em> and <a href=\"/episodes/138\">Naked and Afraid S14E4 \"Sibling Survival\"</a> alongside his brother Warrick",
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
puts "→ #{edited} follow-up edits"
missed.each { |m| puts "  ! #{m}" }
