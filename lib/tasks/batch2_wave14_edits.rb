def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Julio Castano — remove clip-show/preview claim, fix threats
  177 => [
    ["appeared in four episodes during 2016-2017, including \"Into the Wild\", Naked and Afraid S6E9",
     "appeared in Naked and Afraid S6E9"],
    ["heat, poisonous spiders, and a persistent black bear in Florida's Seminole Forest",
     "heat, " + cite("https://www.realitywanted.com/newsitem/7889-naked-and-afraid-danger-within", "alligators, rattlesnakes, and 550-pound black bears in Florida's Seminole Forest")]
  ],

  # Justin Bullard — soften episode count (only 2 canonical verified)
  178 => [
    ["has appeared as a survivalist on Naked and Afraid in five episodes between 2014 and 2020, including Naked and Afraid S3E3",
     "debuted on " + cite("https://www.imdb.com/title/tt3877276/", "Naked and Afraid S3E3")]
  ],

  # Justin True — episode is mentor-format; add Oregon MMA background
  180 => [
    ["Justin True is a Naked and Afraid survivalist (6'4\") who debuted in 2025. More information is available on his official site.\n\nThe challenge was filmed in Mexico. The partner on that challenge was Laura Zerra. The item they brought into the challenge was a mosquito net.",
     "Justin True is a 6'4\" former MMA fighter (\"" + cite("https://www.tapology.com/fightcenter/fighters/43292-justin-true", "The Boogeyman") + "\") from Oregon who debuted on Naked and Afraid S18E7 \"Enter the Queen\" (Mexico, 2025). In a mentor-format episode he was guided by franchise legend Laura Zerra alongside fellow mentee Malik Nyasha."]
  ],

  # Kaiela Hobart — S. Africa specificity; XL S10 detail
  183 => [
    ["Naked and Afraid S11E14 \"21 Miles, 21 Days\" in an African desert, then returned for Naked and Afraid XL 'The Proving Grounds' in Colombia",
     "Naked and Afraid S11E14 \"21 Miles, 21 Days\" in " + cite("https://www.seattletimes.com/entertainment/tv/new-season-of-naked-and-afraid-xl-features-former-wa-resident/", "South Africa") + ", then returned for " + cite("https://press.wbd.com/us/media-release/naked-and-afraid-xl-returns-may-12-8pm-discovery-channel", "Naked and Afraid XL Season 10 \"The Proving Grounds\"") + " in Colombia (2024)"]
  ],

  # Kaila Cumings — Troy NH → Vermont, bump to six times
  184 => [
    ["from Keene, New Hampshire", "from " + cite("https://www.vtmag.com/post/strong-and-sharp", "Troy, New Hampshire, now based in Vermont")],
    ["appeared as a survivalist on Naked and Afraid five times, forging a new custom knife for each season",
     "appeared as a survivalist across the flagship series, XL, Solo, and " + cite("https://www.cheatsheet.com/news/naked-and-afraid-last-one-standing-season-3-cast.html/", "Last One Standing") + ", forging a new custom knife for each season"]
  ],

  # Karra Falkenstein — remove clip-show reference
  188 => [
    ["appearing in episodes including Naked and Afraid S9E4 \"Forbidden Fruit\" and \"Unsurvivable\".",
     "appearing in Naked and Afraid S9E4 \"Forbidden Fruit\"."]
  ],

  # Kate Wentworth — three-time franchise vet
  190 => [
    ["She is a two-time Naked and Afraid contestant, including the episode Naked and Afraid S10E4 \"No Safety in Numbers\",",
     "She is a " + cite("https://thedirect.com/article/naked-and-afraid-last-one-standing-season-2-cast-contestants-2024-episodes-photos", "three-time franchise veteran") + ", having appeared on Naked and Afraid S10E4 \"No Safety in Numbers\" (Panama, 2019), Naked and Afraid XL Season 6 \"The Valley of the Banished\" (South Africa, 2020), and Naked and Afraid: Last One Standing Season 2 (South Africa, 2024),"]
  ],

  # Kayla Groves — 21-day → 14-day
  191 => [
    ["brutal 21-day attempt in South Africa",
     cite("https://tv.apple.com/us/episode/gag-me-with-a-turtle/umc.cmc.3bkac1z7of7yuxt87pslg5pa4", "brutal 14-day attempt in South Africa")]
  ]
}

edited = 0
missed = []
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

# Episode DB fix: S18E7 title typo "Etner" → "Enter"
ep = Episode.joins(:season).where(seasons: { number: 18 }).where(number_in_season: 7).first
if ep && ep.title == "Etner the Queen"
  ep.update!(title: "Enter the Queen")
  puts "→ Fixed S18E7 title: '#{ep.title}'"
end
