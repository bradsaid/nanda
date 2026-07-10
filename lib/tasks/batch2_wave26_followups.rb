def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Warrick Harvey — HTML-aware
  353 => [
    ["has since appeared alongside his brother Shaun in the episode <a href=\"/episodes/138\">Naked and Afraid S14E4 \"Sibling Survival\"</a>",
     "returned in " + cite("https://www.imdb.com/title/tt18673102/", "Naked and Afraid S14E4 \"Sibling Survival\"") + " paired with Louisiana endurance athlete Kat Sibley after his brother Shaun was medically tapped in the preceding episode"]
  ],

  # Waz Addy — Season 3 → Season 1 (LOS) with HTML around it
  355 => [
    ["won the $100,000 grand prize on Season 3 of <a href=\"/seasons\">Naked and Afraid: Last One Standing</a> in 2023",
     "won the $100,000 grand prize on " + cite("https://press.wbd.com/us/media-release/discovery-channel/its-winner-takes-all-brand-new-series-naked-and-afraid-last-one-standing-premiering-0", "Season 1 of Naked and Afraid: Last One Standing") + " in 2023"]
  ],

  # Whitney Hamblin — HTML-aware wrong episode
  359 => [
    ["the 2019 episode <a href=\"/episodes/83\">Naked and Afraid S10E2 \"Frozen and Afraid\"</a>, surviving the full 21-day challenge in a Brazilian jungle",
     "the 2019 episode " + cite("https://www.discovery.com/shows/naked-and-afraid/episodes/youve-got-another-sting-coming", "Naked and Afraid S10E3 \"You've Got Another Sting Coming\"") + ", surviving the full 21-day challenge on a Brazilian island"]
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
