def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  225 => [
    ["where he owns <a href=\"https://essentialinkbodyart.com/\" target=\"_blank\" rel=\"noopener noreferrer\">Essential Ink Body Art</a>",
     "where he works at " + cite("https://go.discovery.com/tv-shows/naked-and-afraid/bios/luke-pytlik/", "Executive Ink in Temecula")]
  ],
  532 => [
    ["A former civil engineer with 11 years of experience, she pivoted careers",
     "A former " + cite("https://telaviva.com.br/27/04/2026/com-dupla-brasileira-largados-e-pelados-campeoes-do-mundo-estreia-no-discovery-e-na-hbo-max/", "civil engineer") + ", she pivoted careers"]
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
puts "→ #{edited} prod fixes"
missed.each { |m| puts "  ! #{m}" }
