def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Zack Buck — alumna → alumnus, day 6 → day 7, add partner name
  363 => [
    ["Southeast Missouri State University outdoor-recreation alumna",
     "Southeast Missouri State University outdoor-recreation alumnus"],
    ["earning a PSR of 8.1 after his partner left on day six",
     "earning a PSR of 8.1 after partner Afften DeShazer " + cite("https://www.imdb.com/title/tt4679446/", "left on day seven due to heat exhaustion")]
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
puts "→ #{edited} final edits"
missed.each { |m| puts "  ! #{m}" }
