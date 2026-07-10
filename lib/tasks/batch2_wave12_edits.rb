def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Jen Taylor — GhP → GHP
  151 => [
    ["She currently produces at GhP Studio.",
     "She currently " + cite("https://www.ghpstudio.com/", "produces at GHP Studio LLC") + "."]
  ],
  # Jennifer Pearce
  154 => [
    ["The partner on that challenge was Steven Lee Hall Jr.",
     "The episode was a " + cite("https://www.imdb.com/title/tt36110470/", "three-survivalist challenge with Steven Lee Hall Jr. and Ally Frueh") + "."]
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

# Optionally rename Jennifer → Jenny Pearce
jp = Survivor.find_by(id: 154)
if jp && jp.full_name == "Jennifer Pearce"
  jp.full_name = "Jenny Pearce"
  jp.slug = nil
  jp.save!
  puts "→ Renamed to '#{jp.full_name}' (slug '#{jp.slug}')"
end
