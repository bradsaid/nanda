def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Keith Busch — soften "four episodes" (clip shows)
  193 => [
    ["who appeared in four episodes of Naked and Afraid in 2014",
     "who appeared on " + cite("https://www.imdb.com/title/tt3642596/", "Naked and Afraid") + " in 2014"]
  ],

  # Kellie Nightlinger — fix "first duo cast" claim + camp location
  194 => [
    ["was part of the very first duo cast on Naked and Afraid",
     "was paired with EJ Snyder on the show's second-aired episode, " + cite("https://www.imdb.com/title/tt3019272/", "S1E2 'Terror in Tanzania' (June 30, 2013)") + " — S1E1 aired one week earlier"],
    ["a free youth adventure camp in Michigan's Upper Peninsula",
     cite("https://www.juneauempire.com/news/wild-woman-finds-home-in-juneau/", "the Angels Among Us free youth adventure camp")]
  ],

  # Kelly Roske — fix "digital creator", add partner + location detail
  195 => [
    ["is a survivalist and digital creator who has divided her time between Hawaii and Mexico",
     "is a " + cite("https://mexiconewsdaily.com/mexico-living/kelly-roske-a-former-naked-survivor-builds-her-dreams-in-mexico/", "nomadic survivalist and self-described earth mother who has lived across Hawaii, the western US, and Mexico")],
    ["finishing her 21-day challenge in South Africa alone after her partner left on day four",
     "finishing her 21-day challenge along South Africa's Limpopo River alone after her partner Eric Jorgenson left on day four due to injury"]
  ],

  # Kyle Malo — add football coach + podcast name
  203 => [
    ["Kyle Malo is a Naked and Afraid superfan",
     "Kyle Malo is a " + cite("https://www.sportskeeda.com/pop-culture/naked-afraid-season-17-episode-7-superfans-bring-bougie-columbian-jungle", "football coach") + " and Naked and Afraid superfan"],
    ["podcaster MaLu Beyonce",
     "podcaster MaLu Beyonce (host of A Naked and Afraid Podcast: Oh Heck NAA)"]
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
