# Remove broken external links from survivor bios, preserving display text.

REPLACEMENTS = [
  # id, find (full <a> tag), replace (bare text)
  [149, %q(<a href="https://jasonszabo.com/" target="_blank" rel="noopener noreferrer">jasonszabo.com</a>),
        "his personal website"],
  [36,  %q(<a href="https://www.novoexpeditions.com" target="_blank" rel="noopener noreferrer">Novo Expeditions</a>),
        "Novo Expeditions"],
  [163, %q(<a href="https://primitivegrind.com" target="_blank" rel="noopener noreferrer">Primitive Grind</a>),
        "Primitive Grind"],
  [339, %q(<a href="https://www.lairsurvival.com" target="_blank" rel="noopener noreferrer">Lair Survival</a>),
        "Lair Survival"],
  [79,  %q(<a href="https://www.calpoly.edu/directory/ckohlen" target="_blank" rel="noopener noreferrer">registered dietitian based in San Luis Obispo, California</a>),
        "registered dietitian based in San Luis Obispo, California"]
]

edited = 0; missed = []
REPLACEMENTS.each do |sid, find, replace|
  s = Survivor.find_by(id: sid); next unless s
  if s.bio.to_s.include?(find)
    s.update!(bio: s.bio.sub(find, replace))
    edited += 1
    puts "  E #{s.full_name}"
  else
    missed << "#{s.full_name} (id=#{sid})"
  end
end
puts "→ #{edited} edits"
missed.each { |m| puts "  ! #{m}" }
