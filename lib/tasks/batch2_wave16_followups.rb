def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Lee Diehl — remove clip-show (HTML variant)
  216 => [
    [", including the episodes <em>\"Unsurvivable\"</em> and <a href=\"/episodes/75\">Naked and Afraid S9E8 \"Burnt to a Crisp\"</a>.",
     " on <a href=\"/episodes/75\">Naked and Afraid S9E8 \"Burnt to a Crisp\"</a>."]
  ],

  # Lee Trew — co-founded → founded (HTML variant, existing link stays)
  217 => [
    ["co-founded <a href=\"https://www.bluegumbushcraft.com.au/\" target=\"_blank\" rel=\"noopener noreferrer\">Bluegum Bushcraft</a>",
     "founded <a href=\"https://www.bluegumbushcraft.com.au/\" target=\"_blank\" rel=\"noopener noreferrer\">Bluegum Bushcraft</a>"]
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
