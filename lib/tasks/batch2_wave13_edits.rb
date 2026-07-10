def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # John Hogfoss — Mylee → Mylaena
  167 => [
    ["partner Mylee Monks",
     cite("https://www.imdb.com/title/tt29224482/", "partner Mylaena Monks")]
  ],
  # Jon Hart — S10E5 Threesome → S10E6 Baked Alaskan
  170 => [
    ["Naked and Afraid S10E5 \"Threesome\" alongside partner Gwen Grimes",
     cite("https://www.imdb.com/title/tt10345024/", "Naked and Afraid S10E6 \"Baked Alaskan\" alongside partner Gwen Grimes")]
  ],
  # Jolie Kathleen — Love & Adventure → Please Don't Eat Me
  168 => [
    ["returned in \"Love &amp; Adventure\"",
     "returned in " + cite("https://www.tvguide.com/tvshows/naked-and-afraid/episodes-season-19/1000484646/", "\"Please Don't Eat Me\"") + " (Kalahari Desert)"],
    ["returned in \"Love & Adventure\"",
     "returned in " + cite("https://www.tvguide.com/tvshows/naked-and-afraid/episodes-season-19/1000484646/", "\"Please Don't Eat Me\"") + " (Kalahari Desert)"]
  ],
  # Jonathan Klay — remove Snaketacular
  171 => [
    [", and returned for the \"Snaketacular\" episode",
     ""],
    [", and returned for the <em>\"Snaketacular\"</em> episode",
     ""]
  ],
  # Julie Wright — soften episode count and remove Snaketacular
  176 => [
    ["She appeared on Naked and Afraid in four episodes between 2013 and 2014, including Naked and Afraid S1E5 \"Breaking Borneo\", a 21-day challenge in Sabah, Borneo with partner Puma Cabra, and later \"Snaketacular\".",
     "She appeared on Naked and Afraid S1E5 \"Breaking Borneo\", a 21-day challenge in Sabah, Borneo with partner Puma Cabra."]
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

# DB rename: Joesph Prouse → Joseph Prouse
jp = Survivor.find_by(id: 166)
if jp && jp.full_name == "Joesph Prouse"
  jp.full_name = "Joseph Prouse"; jp.slug = nil; jp.save!
  puts "→ Renamed to '#{jp.full_name}' (slug '#{jp.slug}')"
end
