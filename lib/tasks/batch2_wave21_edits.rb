def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Rachel Strohl — WV → Western PA
  280 => [
    ["from West Virginia",
     "from " + cite("https://triblive.com/aande/movies-tv/tv-talk-former-pittsburgher-gets-naked-destination-fear-visits-waynesburg/", "Western Pennsylvania")]
  ],

  # Rusty Thomas — remove wrong Cheeny Plante partner, note team format
  290 => [
    ["The partner on that challenge was Cheeny Plante.",
     "The men's team also included " + cite("https://www.imdb.com/title/tt19711070/", "Jared Guillien") + ", competing against Cheeny Plante and Rebel Blalock."]
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
