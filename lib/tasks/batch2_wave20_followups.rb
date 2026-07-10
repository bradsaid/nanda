def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Pearson Caldwell — full HTML-aware rewrite
  402 => [
    ["Pearson Caldwell is the outdoorsman behind the Country Tactical (CoTac) social channels, which focus on hunting and tactical content, and he runs the outdoor brand <a href=\"https://hardshipsupply.com/\" target=\"_blank\" rel=\"noopener noreferrer\">Hardship Supply</a>. He competed in <a href=\"/seasons\">Naked and Afraid</a> Season 19, where in the episode <em>\"Clash of the Survivalists\"</em> a laid-back hunter and an opinionated adventure guide attempted a 21-day challenge in Zambia.",
     "Pearson Caldwell is an East Texas outdoorsman behind " + cite("https://www.instagram.com/countrytactical/", "Country Tactical (CoTac)") + " (~1M Instagram followers) who went viral in 2023 building a log cabin by hand in Van Zandt County. He also runs the outdoor brand <a href=\"https://hardshipsupply.com/\" target=\"_blank\" rel=\"noopener noreferrer\">Hardship Supply</a>. He competed on " + cite("https://www.imdb.com/news/ni65719243/", "Naked and Afraid S19E3 \"Like, Subscribe and Survive\"") + " — a 14-day challenge in Thailand featuring five social-media influencers."]
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
