def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Tyler Whitney — remove Kalahari
  438 => [
    ["a challenge filmed in the Kalahari Desert",
     "a challenge " + cite("https://www.imdb.com/title/tt41449243/", "filmed in Zambia")]
  ],

  # Warrick Harvey — clarify Kat Sibley pairing
  353 => [
    ["has since appeared alongside his brother Shaun in the episode Naked and Afraid S14E4 \"Sibling Survival\"",
     "returned in Naked and Afraid S14E4 " + cite("https://www.imdb.com/title/tt18673102/", "\"Sibling Survival\"") + " (Zambia, 2022) paired with Louisiana endurance athlete Kat Sibley after his brother Shaun was medically tapped in the preceding episode"]
  ],

  # Waylon Harper — 14-day → 21-day + add partner Julia Bulinsky
  354 => [
    ["taking on a 14-day challenge in a dense Mexican rainforest",
     "taking on a " + cite("https://www.discovery.com/shows/naked-and-afraid/episodes/next-gen-survival", "21-day challenge alongside fellow next-gen survivalist Julia Bulinsky in a dense Mexican rainforest")]
  ],

  # Waz Addy — Season 3 → Season 1 (LOS)
  355 => [
    ["won the $100,000 grand prize on Season 3 of Naked and Afraid: Last One Standing in 2023",
     "won the $100,000 grand prize on " + cite("https://press.wbd.com/us/media-release/discovery-channel/its-winner-takes-all-brand-new-series-naked-and-afraid-last-one-standing-premiering-0", "Season 1 of Naked and Afraid: Last One Standing") + " in 2023"]
  ],

  # Whitney Hamblin — wrong episode
  359 => [
    ["Naked and Afraid S10E2 \"Frozen and Afraid\", surviving the full 21-day challenge in a Brazilian jungle",
     cite("https://www.discovery.com/shows/naked-and-afraid/episodes/youve-got-another-sting-coming", "Naked and Afraid S10E3 \"You've Got Another Sting Coming\"") + ", surviving the full 21-day challenge on a Brazilian island"]
  ],

  # Zach Benton — 17 of 21 → full 21 (17 solo)
  362 => [
    ["completing 17 days of the 21-day challenge solo after his partner tapped out on day four",
     "completing " + cite("https://www.offgridweb.com/preparation/naked-and-afraid-the-naked-truth/", "all 21 days, the last 17 solo after his partner departed ill on day four")]
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

# DB fix: trim trailing space from S19E8 title
ep = Episode.where("title LIKE ?", "Clash of the Survivalists %").first
if ep
  ep.update!(title: ep.title.strip)
  puts "→ Trimmed episode title: '#{ep.title}'"
end
