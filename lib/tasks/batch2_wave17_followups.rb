def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Luke Pytlik — for prod which still has original text
  225 => [
    ["where he owns Essential Ink Body Art. He",
     "where he works at " + cite("https://go.discovery.com/tv-shows/naked-and-afraid/bios/luke-pytlik/", "Executive Ink in Temecula") + ". He"],
    ["owns Essential Ink Body Art",
     "works at " + cite("https://go.discovery.com/tv-shows/naked-and-afraid/bios/luke-pytlik/", "Executive Ink in Temecula")]
  ],

  # Marina Lara Fukushima — remove unverified details
  532 => [
    ["Marina Lara Fukushima is a Brazilian survivalist and rural producer based at her property Sítio Trópico de Capricórnio, where she focuses on bio-construction and sustainable living. A former civil engineer with 11 years of experience, she pivoted careers to embrace a wilderness lifestyle.",
     "Marina Lara Fukushima is a Brazilian survivalist and rural producer, a former " + cite("https://telaviva.com.br/27/04/2026/com-dupla-brasileira-largados-e-pelados-campeoes-do-mundo-estreia-no-discovery-e-na-hbo-max/", "civil engineer") + " who pivoted careers to embrace a wilderness lifestyle focused on bio-construction and sustainable living."]
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
