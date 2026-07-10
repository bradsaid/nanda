def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Justin Bullard — soften episode count
  178 => [
    ["in five episodes between 2014 and 2020, including <a href=\"/episodes/15\">Naked and Afraid S3E3 \"Blood in the Water\"</a>, filmed in the Bahamas with partner Dani Julien.",
     "on " + cite("https://www.imdb.com/title/tt3877276/", "Naked and Afraid S3E3 \"Blood in the Water\"") + ", filmed in the Bahamas with partner Dani Julien in 2014."]
  ],

  # Justin True — mentor-format rewrite (bio has HTML wrappers)
  180 => [
    ["Justin True is a <a href=\"/seasons\">Naked and Afraid</a> survivalist (6'4\") who debuted in 2025. More information is available on his <a href=\"https://www.justintrueofficial.com/\" target=\"_blank\" rel=\"noopener noreferrer\">official site</a>.\n\nThe challenge was filmed in <a href=\"/episodes/by_country/Mexico\">Mexico</a>. The partner on that challenge was Laura Zerra. The item they brought into the challenge was a mosquito net.",
     "Justin True is a 6'4\" former MMA fighter (\"" + cite("https://www.tapology.com/fightcenter/fighters/43292-justin-true", "The Boogeyman") + "\") from Oregon who debuted on Naked and Afraid S18E7 \"Enter the Queen\" (Mexico, 2025). In a mentor-format episode he was guided by franchise legend Laura Zerra alongside fellow mentee Malik Nyasha. More information is available on his <a href=\"https://www.justintrueofficial.com/\" target=\"_blank\" rel=\"noopener noreferrer\">official site</a>."]
  ],

  # Kaiela Hobart — S. Africa + XL S10 details
  183 => [
    ["<a href=\"/episodes/113\">Naked and Afraid S11E14 \"21 Miles, 21 Days\"</a> in an African desert, then returned for <a href=\"/seasons\">Naked and Afraid XL</a> 'The Proving Grounds' in Colombia and <a href=\"/seasons\">Naked and Afraid: Last One Standing</a> in 2025.",
     "<a href=\"/episodes/113\">Naked and Afraid S11E14 \"21 Miles, 21 Days\"</a> in " + cite("https://www.seattletimes.com/entertainment/tv/new-season-of-naked-and-afraid-xl-features-former-wa-resident/", "South Africa") + ", then returned for " + cite("https://press.wbd.com/us/media-release/naked-and-afraid-xl-returns-may-12-8pm-discovery-channel", "Naked and Afraid XL Season 10 \"The Proving Grounds\"") + " in Colombia (2024) and <a href=\"/seasons\">Naked and Afraid: Last One Standing</a> in 2025."]
  ],

  # Karra Falkenstein — remove clip-show
  188 => [
    [", appearing in episodes including <a href=\"/episodes/71\">Naked and Afraid S9E4 \"Forbidden Fruit\"</a> and <em>\"Unsurvivable\"</em>.",
     ", appearing in <a href=\"/episodes/71\">Naked and Afraid S9E4 \"Forbidden Fruit\"</a>."]
  ],

  # Kate Wentworth — three-time
  190 => [
    ["She is a two-time <a href=\"/seasons\">Naked and Afraid</a> contestant, including the episode <a href=\"/episodes/85\">Naked and Afraid S10E4 \"No Safety in Numbers\"</a>, and runs",
     "She is a " + cite("https://thedirect.com/article/naked-and-afraid-last-one-standing-season-2-cast-contestants-2024-episodes-photos", "three-time franchise veteran") + ", having appeared on <a href=\"/episodes/85\">Naked and Afraid S10E4 \"No Safety in Numbers\"</a> (Panama, 2019), Naked and Afraid XL Season 6 \"The Valley of the Banished\" (South Africa, 2020), and Naked and Afraid: Last One Standing Season 2 (South Africa, 2024). She runs"]
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
puts "→ #{edited} follow-up edits"
missed.each { |m| puts "  ! #{m}" }
