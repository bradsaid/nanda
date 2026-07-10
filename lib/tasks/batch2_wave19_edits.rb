def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Michael Jefferson — add partner name Ashley
  251 => [
    ["paired with a Rhode Island bartender for a 21-day challenge in Botswana",
     "paired with " + cite("https://www.heraldnet.com/life/marysville-native-braves-elements-on-discoverys-naked-and-afraid/", "Rhode Island bartender Ashley for a 21-day challenge in Botswana")]
  ],

  # Mike Douglas — school lineage
  255 => [
    ["is the founder of Maine Primitive Skills School in Augusta, Maine, where he has taught wilderness skills since 1989",
     "founded the wilderness school that became " + cite("https://www.maineprimitive.com/our-story", "Maine Primitive Skills School") + " (Augusta, Maine) — first established in 1989 and renamed under its current name in 1998"]
  ],

}

edited = 0; missed = []
EDITS.each do |sid, replacements|
  s = Survivor.find_by(id: sid); next unless s
  before = s.bio.to_s; after = before.dup; applied = false
  replacements.each do |find, replace|
    if after.include?(find) && find != replace; after = after.sub(find, replace); applied = true; end
  end
  if applied; s.update!(bio: normalize(after)); edited += 1; puts "  E #{s.full_name}"
  else; missed << "#{s.full_name} (id=#{sid})"; end
end
puts "→ #{edited} edits"
missed.each { |m| puts "  ! #{m}" }
