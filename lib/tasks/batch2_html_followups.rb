# Post-session cleanup: catch HTML-tag-mismatch misses across batch 2 waves.
def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

# Fetch current-state bios and apply edits keyed by content patterns that
# tolerate the embedded <a> tags in the DB.
EDITS = {
  # John Hogfoss — partner Mylee → Mylaena
  167 => [["partner Mylee Monks", cite("https://www.imdb.com/title/tt29224482/", "partner Mylaena Monks")]],

  # Jon Hart — S10E5 Threesome → S10E6 Baked Alaskan (allow HTML link)
  170 => [
    [">Naked and Afraid S10E5 \"Threesome\"</a> alongside partner Gwen Grimes",
     ">Naked and Afraid S10E6 \"Baked Alaskan\"</a> alongside partner Gwen Grimes"],
    ["S10E5 \"Threesome\" alongside partner Gwen Grimes",
     "S10E6 \"Baked Alaskan\" alongside partner Gwen Grimes"]
  ],

  # Jolie Faulkner — Love & Adventure → Please Don't Eat Me (multiple entity encodings)
  168 => [
    ["returned in \"Love &amp; Adventure\"",
     "returned in " + cite("https://www.tvguide.com/tvshows/naked-and-afraid/episodes-season-19/1000484646/", "\"Please Don't Eat Me\"") + " (Kalahari Desert)"],
    ["returned in \"Love & Adventure\"",
     "returned in " + cite("https://www.tvguide.com/tvshows/naked-and-afraid/episodes-season-19/1000484646/", "\"Please Don't Eat Me\"") + " (Kalahari Desert)"],
    ["Love &amp; Adventure",
     "Please Don't Eat Me"]
  ],

  # Jonathan Klay — remove Snaketacular clause
  171 => [
    [", and returned for the \"Snaketacular\" episode.", "."],
    [", and returned for the <em>\"Snaketacular\"</em> episode.", "."],
    [" and returned for the <em>\"Snaketacular\"</em> episode", ""],
    [", and returned for the Snaketacular episode.", "."]
  ],

  # Julie Wright — soften episode count and remove Snaketacular
  176 => [
    ["four episodes between 2013 and 2014, including",
     "a first-season episode: "],
    [", and later \"Snaketacular\".", "."],
    [", and later <em>\"Snaketacular\"</em>.", "."]
  ],

  # Also retry prior misses — Charlie Frattini, Cole Wilks, Cory Williams, Daren Jackson
  # (using HTML-aware find-strings)
  70 => [
    [", taking on a 40-day challenge in Ecuador.",
     ", taking on the " + cite("https://thecinemaholic.com/naked-and-afraid-xl-filming-locations/", "40-day XL Season 3 challenge in Ecuador") + "."]
  ],
  78 => [
    ["with partner Michelle Armogida.",
     "with partner Shell (Michelle) Armogida."]
  ],
  80 => [
    ["A former California Department of Forestry firefighter, certified EMT, and stuntman, he appeared",
     "He appeared"]
  ],
  89 => [
    ["season 11 episode <a href=\"/episodes/106\">Naked and Afraid S11E3 \"Bahama Drama\"</a>",
     "season 11 episode <a href=\"/episodes/106\">Naked and Afraid S11E3 \"Bahama Drama\"</a>"] # already fixed - no-op guard
  ],
  113 => [
    ["for a 14-day challenge in Mexico's Yucatan Peninsula on \"Alone and Terrified\".",
     "for a 14-day Yucatan Peninsula fan challenge on \"Couch to Cave\" (S18E2)."]
  ]
}

edited = 0; missed = []
EDITS.each do |sid, replacements|
  s = Survivor.find_by(id: sid); next unless s
  before = s.bio.to_s; after = before.dup; applied = false
  replacements.each do |find, replace|
    if after.include?(find); after = after.sub(find, replace); applied = true; end
  end
  if applied && after != before
    s.update!(bio: normalize(after)); edited += 1; puts "  E #{s.full_name}"
  end
end
puts "→ #{edited} follow-up edits"
