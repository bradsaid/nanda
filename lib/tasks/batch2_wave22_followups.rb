def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Sam Strong rewrite — HTML-aware for existing markup
  301 => [
    ["Samuel Smith is a survivalist who appeared on <a href=\"/seasons\">Naked and Afraid</a> in the 2024 episode <a href=\"/episodes/167\">Naked and Afraid S17E4 \"Surviving the Road to Recovery\"</a>, completing a 21-day challenge in South Africa alongside Sarah Barnett amid crocodiles, lions and venomous snakes.",
     "Sam Strong is a " + cite("https://www.pressdemocrat.com/article/news/2-sonoma-county-residents-will-bare-all-and-try-to-survive-on-upcoming-nak/", "Rohnert Park, California") + " survivalist who appeared on <a href=\"/episodes/167\">Naked and Afraid S17E4 \"Surviving the Road to Recovery\"</a>, completing a 21-day South African challenge alongside Sarah Barnett. The episode's title works on two levels: the pair navigated crocodiles, lions and venomous snakes while drawing on their shared sobriety journeys (Sam 10 years sober, Sarah 5)."]
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
