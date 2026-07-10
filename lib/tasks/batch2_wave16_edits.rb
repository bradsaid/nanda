def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Laura Zerra — book title fix
  208 => [
    ["A Modern Guide to Knife-making",
     cite("https://www.amazon.com/Modern-Guide-Knifemaking-Step-step/dp/1631595059", "A Modern Guide to Knifemaking")]
  ],

  # Laurae Hughes — disambiguate S11E9 (Baja) from S11E17 (Montana)
  209 => [
    ["Her debut challenge was shot in the Sierra de Juarez mountains of Baja, Mexico, where she was paired with Canadian Christopher James.",
     "Her debut (S11E9) was shot in the " + cite("https://www.peninsuladailynews.com/news/chimacum-woman-to-be-on-an-episode-of-naked-afraid/", "Sierra de Juarez mountains of Baja, Mexico") + ", where she was paired with Canadian Christopher James. Her second appearance, \"Snow Daze\" (S11E17), was filmed in " + cite("https://kyssfm.com/montana-snow-daze-episode-of-naked-and-afraid-watch/", "the Rockies of Montana") + "."]
  ],

  # Lauren Fagen — fix lion attack description
  211 => [
    ["where she was dragged into a cage as an 18-year-old volunteer and saved by another volunteer",
     "where at age 18 a " + cite("https://www.cbc.ca/news/canada/montreal/montrealer-mauled-by-lion-says-wildlife-reserve-put-her-in-danger-1.1372273", "male lion grabbed her leg through the bars of a feeding enclosure and a second lion joined the attack before colleagues drove them off with broomsticks")]
  ],

  # Lee Diehl — remove clip-show reference
  216 => [
    [", including the episodes \"Unsurvivable\" and Naked and Afraid S9E8 \"Burnt to a Crisp\"",
     " on Naked and Afraid S9E8 \"Burnt to a Crisp\""]
  ],

  # Lee Trew — "co-founded" → "founded"
  217 => [
    ["co-founded Bluegum Bushcraft",
     "founded " + cite("https://www.bluegumbushcraft.com.au/about-us.html", "Bluegum Bushcraft")]
  ],

  # Lilly Jammerbund — Vienna → Lower Austria
  218 => [
    ["born in Vienna",
     "born in " + cite("https://www.survivallilly.at/impressum/", "Lower Austria")]
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

# DB fix: S16E5 Odd Man Out air date 2024-11-12 → 2023-11-12
ep = Episode.find_by(title: "Odd Man Out")
if ep && ep.air_date.to_s == "2024-11-12"
  ep.update!(air_date: "2023-11-12")
  puts "→ Fixed S16E5 'Odd Man Out' air date: 2023-11-12"
end
