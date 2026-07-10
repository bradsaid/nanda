def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Matt Strutzel — remove clip-show inflation + fix region
  239 => [
    ["He appeared on Naked and Afraid across three episodes in 2014-2015, including Naked and Afraid S3E11 \"Dunes of Despair\", completing a challenge in Brazil's North Region while his partner Honora Bowen tapped out from heat exhaustion.",
     "He completed " + cite("https://www.imdb.com/title/tt4067678/", "Naked and Afraid S3E11 \"Dunes of Despair\"") + " (2014) in Brazil's Northeast Region after his partner Honora Bowen tapped out."]
  ],

  # Max Djenohan — NBC → USA Network
  241 => [
    ["NBC's Race to Survive Alaska",
     cite("https://www.usanetwork.com/race-to-survive-alaska/credits/contestant/max-djenohan-christian-junkar", "USA Network's Race to Survive Alaska")]
  ],

  # McKenzie Clark — soften "3 episodes"
  242 => [
    ["She appeared on Naked and Afraid across three episodes in 2016-2017, including Naked and Afraid S8E2 \"Texan Torture\" with Scott Thompson",
     "She appeared on " + cite("https://www.imdb.com/title/tt7239420/", "Naked and Afraid S8E2 \"Texan Torture\"") + " (2017) with Scott Thompson"]
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

# DB fixes
# 1. S17E3 title: Colombian Cave Woman -> Colombian Cave Women
ep = Episode.where(title: "Colombian Cave Woman").first
if ep
  ep.update!(title: "Colombian Cave Women")
  puts "→ Fixed S17E3 title: '#{ep.title}'"
end

# 2. Matt Wright appearance shows S11E109 — investigate/fix if bogus
ep2 = Episode.where("number_in_season = 109").first
if ep2
  puts "→ Found suspect episode S#{ep2.season&.number}E#{ep2.number_in_season} '#{ep2.title}' — needs manual review"
end
