def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Luke Pytlik — Essential Ink Wildomar → Executive Ink Temecula
  225 => [
    ["owns Essential Ink Body Art",
     "works at " + cite("https://go.discovery.com/tv-shows/naked-and-afraid/bios/luke-pytlik/", "Executive Ink in Temecula")]
  ],

  # Maci Bookout — day 2 → day 1
  227 => [
    ["tapped out on day two",
     cite("https://popculture.com/reality-tv/news/maci-bookout-naked-and-afraid-bails-after-day-one/", "tapped out on day one")]
  ],

  # Makani Nalu — CBS → MTV, Malibu → Venice
  228 => [
    ["won the debut season of CBS's Stranded with a Million Dollars in 2017",
     "won the debut season of " + cite("https://en.wikipedia.org/wiki/Stranded_with_a_Million_Dollars", "MTV's Stranded with a Million Dollars") + " in 2017"],
    ["Now a Malibu-based yoga instructor",
     "Now a " + cite("https://thecinemaholic.com/naked-and-afraid-xl-makani-nalu/", "Venice, California-based yoga instructor")]
  ],

  # Marissa Joy — soften "birding photographer" to match Discovery framing
  235 => [
    ["is an outdoors enthusiast and birding photographer who appeared",
     "is a " + cite("https://www.discovery.com/shows/naked-and-afraid/episodes/abandoned", "geologist and outdoors generalist") + " (climbing, ice climbing, cave diving, birding) who appeared"]
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
