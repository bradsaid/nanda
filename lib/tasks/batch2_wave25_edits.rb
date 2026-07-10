def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Thomas Virgets — brothers, not twins
  337 => [
    ["alongside his twin brother Warren. The brothers were the show's first sibling pair",
     "alongside his " + cite("https://www.theadvocate.com/baton_rouge/entertainment_life/movies_tv/baton-rouge-brothers-take-on-the-african-savanna-in-naked-and-afraid-season-premiere/article_0de171c6-5367-11ea-adfc-4f5bf20d126c.html", "older brother Warren") + ". The brothers were among the show's first sibling pairs"]
  ],

  # Tori Huggins — wrong episode title
  365 => [
    ["Naked and Afraid in the 2026 episode \"Clash of the Survivalists\"",
     "Naked and Afraid in the " + cite("https://tvtonight.net/naked-and-afraid-flesh-and-fangs-launches-season-19-in-the-dangerous-everglades/", "2026 Season 19 premiere \"Flesh and Fangs\"")]
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

# DB rename: Theresa Owens → Threasa Owens (per IMDb)
to = Survivor.find_by(id: 336)
if to && to.full_name == "Theresa Owens"
  to.full_name = "Threasa Owens"; to.slug = nil; to.save!
  puts "→ Renamed to '#{to.full_name}' (slug '#{to.slug}')"
end
