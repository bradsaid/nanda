def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Sabrina Mergenthaler — remove unverified biz claim
  294 => [
    ["is a Snellville, Georgia mother and outdoor adventurer who founded She Inspires Adventures, a platform empowering women to pursue solo outdoor travel. She appeared",
     "is a " + cite("https://www.ajc.com/entertainment/television/snellville-mom-survives-naked-and-afraid/AmO8DfcpdacDq0gpmHIhhO/", "Snellville, Georgia mother and outdoor adventurer") + " who appeared"]
  ],

  # Sam Mouzer — Mojave Desert → Sabinoso Wilderness, NM
  296 => [
    ["Survival Lilly in the Mojave Desert",
     "Survival Lilly in the " + cite("https://sports.yahoo.com/naked-afraid-season-filmed-sabinoso-043300022.html", "Sabinoso Wilderness of New Mexico")]
  ],

  # Samuel Smith — rewrite bio for Sam Strong (sobriety theme)
  301 => [
    ["Samuel Smith is a survivalist who appeared on Naked and Afraid in the 2024 episode Naked and Afraid S17E4 \"Surviving the Road to Recovery\", completing a 21-day challenge in South Africa alongside Sarah Barnett amid crocodiles, lions and venomous snakes.",
     "Sam Strong is a " + cite("https://www.pressdemocrat.com/article/news/2-sonoma-county-residents-will-bare-all-and-try-to-survive-on-upcoming-nak/", "Rohnert Park, California") + " survivalist who appeared on Naked and Afraid S17E4 \"Surviving the Road to Recovery\", completing a 21-day South African challenge alongside Sarah Barnett. The episode's title works on two levels: the pair navigated crocodiles, lions and venomous snakes while drawing on their shared sobriety journeys (Sam 10 years sober, Sarah 5)."]
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

# DB rename: Samuel Smith → Sam Strong
ss = Survivor.find_by(id: 301)
if ss && ss.full_name == "Samuel Smith"
  ss.full_name = "Sam Strong"; ss.slug = nil; ss.save!
  puts "→ Renamed to '#{ss.full_name}' (slug '#{ss.slug}')"
end
