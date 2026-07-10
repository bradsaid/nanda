def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  193 => [
    ["who appeared in four episodes of <a href=\"/seasons\">Naked and Afraid</a> in 2014. His credits include <a href=\"/episodes/10\">Naked and Afraid S2E4 \"Paradise Lost\"</a>",
     "who appeared on <a href=\"/seasons\">Naked and Afraid</a> in 2014's <a href=\"/episodes/10\">Naked and Afraid S2E4 \"Paradise Lost\"</a>"]
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
