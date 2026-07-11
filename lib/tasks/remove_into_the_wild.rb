# Remove "Into the Wild" clip-show/preview-reel references from bios.
# S6E1 "Into the Wild" is a Season 6 premiere preview compilation, not a
# canonical challenge episode per project rules.

EDITS = [
  # Julio Castano — remove leading "Into the Wild" from the list
  [177, %q(appeared in Naked and Afraid S6E9 "The Danger Within"),
        %q(appeared in <em>"Into the Wild"</em>, <a href="/episodes/47">Naked and Afraid S6E9 "The Danger Within"</a>)],

  # Chalese Meyer — remove trailing " and 'Into the Wild'"
  [68, %q("King of the Forest"</a>, and has spoken publicly),
       %q("King of the Forest"</a> and <em>"Into the Wild"</em>, and has spoken publicly)],

  # Geoff Wilson — remove leading "Into the Wild" (2016, Panama) and
  [124, %q(appeared on <a href="/seasons">Naked and Afraid</a> in the episode <a href="/episodes/58">Naked and Afraid S7E8 "Unhinged"</a> (2017)),
        %q(appeared on <a href="/seasons">Naked and Afraid</a> in the episodes <em>"Into the Wild"</em> (2016, Panama) and <a href="/episodes/58">Naked and Afraid S7E8 "Unhinged"</a> (2017))],

  # Clarence Gilmer II — remove leading "Into the Wild", from the list
  [76, %q(<a href="/episodes/50">Naked and Afraid S6E13 "Strength in Pain"</a>, <em>"Man on Fire"</em>, and <em>"Out of Africa"</em>),
       %q(<em>"Into the Wild"</em>, <a href="/episodes/50">Naked and Afraid S6E13 "Strength in Pain"</a>, <em>"Man on Fire"</em>, and <em>"Out of Africa"</em>)]
]

edited = 0; missed = []
EDITS.each do |sid, replacement, find|
  s = Survivor.find_by(id: sid); next unless s
  if s.bio.to_s.include?(find)
    s.update!(bio: s.bio.sub(find, replacement))
    edited += 1
    puts "  E #{s.full_name}"
  else
    missed << "#{s.full_name} (id=#{sid})"
  end
end
puts "→ #{edited} edits"
missed.each { |m| puts "  ! #{m}" }
