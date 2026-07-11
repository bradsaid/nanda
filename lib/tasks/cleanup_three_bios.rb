def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Jolie Faulkner — "Love & Adventure" (clip show) → "Please Don't Eat Me"
  168 => [
    [%q(returned in <em>"Love & Adventure"</em>),
     "returned in " + cite("https://www.tvguide.com/tvshows/naked-and-afraid/episodes-season-19/1000484646/", %q("Please Don't Eat Me")) + " (Kalahari Desert)"]
  ],

  # Malik Nyasha — fix "Etner" typo in display text
  229 => [
    [%q(<a href="/episodes/182">Naked and Afraid S18E7 "Etner the Queen"</a>),
     %q(<a href="/episodes/182">Naked and Afraid S18E7 "Enter the Queen"</a>)]
  ],

  # Pearson Caldwell — remove duplicate trailing "See ..." sentence
  402 => [
    [%q( See <a href="/episodes/382">Naked and Afraid S19E3 "Like, Subscribe and Survive"</a>.),
     ""]
  ]
}

edited = 0; missed = []
EDITS.each do |sid, replacements|
  s = Survivor.find_by(id: sid); next unless s
  before = s.bio.to_s; after = before.dup; applied = false
  replacements.each do |find, replace|
    if after.include?(find); after = after.sub(find, replace); applied = true; end
  end
  if applied; s.update!(bio: after.gsub(/[ \t]{2,}/, " ").strip); edited += 1; puts "  E #{s.full_name}"
  else; missed << "#{s.full_name} (id=#{sid})"; end
end
puts "→ #{edited} edits"
missed.each { |m| puts "  ! #{m}" }
