def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Steve Hansen — HTML-aware clip-inflation fix
  326 => [
    ["appeared on <a href=\"/seasons\">Naked and Afraid</a> across three episodes between 2015 and 2017",
     "appeared on " + cite("https://www.imdb.com/title/tt4651602/", "Naked and Afraid S4E2 \"Rumble in the Jungle\"") + " in 2015"]
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

# DB rename: Teal Bulthius → Teal Bulthuis
tb = Survivor.find_by(id: 334)
if tb && tb.full_name == "Teal Bulthius"
  tb.full_name = "Teal Bulthuis"; tb.slug = nil; tb.save!
  puts "→ Renamed to '#{tb.full_name}' (slug '#{tb.slug}')"
end
