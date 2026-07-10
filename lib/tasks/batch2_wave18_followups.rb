def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Matt Strutzel — HTML-aware
  239 => [
    ["He appeared on <a href=\"/seasons\">Naked and Afraid</a> across three episodes in 2014-2015, including <a href=\"/episodes/23\">Naked and Afraid S3E11 \"Dunes of Despair\"</a>, completing a challenge in Brazil's North Region while his partner Honora Bowen tapped out from heat exhaustion.",
     "He completed <a href=\"/episodes/23\">Naked and Afraid S3E11 \"Dunes of Despair\"</a> (2014) in Brazil's Northeast Region after his partner Honora Bowen tapped out."]
  ],

  # McKenzie Clark — HTML-aware
  242 => [
    ["She appeared on <a href=\"/seasons\">Naked and Afraid</a> across three episodes in 2016-2017, including <a href=\"/episodes/63\">Naked and Afraid S8E2 \"Texan Torture\"</a> with Scott Thompson",
     "She appeared on <a href=\"/episodes/63\">Naked and Afraid S8E2 \"Texan Torture\"</a> (2017) with Scott Thompson"]
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
