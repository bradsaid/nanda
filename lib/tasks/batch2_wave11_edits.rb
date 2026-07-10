def normalize(s); s.gsub(/[ \t]{2,}/, " ").strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Jaclin Owen — NW Indiana softening
  137 => [
    ["paralegal from Northwest Indiana",
     "paralegal from " + cite("https://www.aetv.com/shows/60-days-in/cast/jaclin", "Indiana")]
  ],
  # Jake Johnson — proposal correction
  139 => [
    ["made television history by proposing to his girlfriend on camera during the challenge",
     cite("https://popculture.com/reality-tv/news/naked-and-afraid-contestant-reveals-what-went-into-season-premiere-surprise-engagement/", "proposed to his girlfriend shortly after returning home") + "; the engagement was revealed on the season premiere"]
  ],
  # Holly Simmons — partner correction
  134 => [
    ["The partner on that challenge was Amber Hargrove.",
     "The partner on that challenge was " + cite("https://staytunedmag.com/tv-news/2016/06/05/recap-naked-afraid-namibia-23-days/", "Don Nguyen") + "; she tapped out early, and Amber Hargrove joined as Don's replacement."]
  ],
  # Jake Nodar — Amazon → South Africa
  140 => [
    ["his time in the Amazon was cut short by a serious illness",
     "his time in " + cite("https://www.ibtimes.com/naked-afraid-xl-star-jake-nodar-gives-health-update-how-horse-trainer-recovered-south-2409374", "XL South Africa was cut short by a serious liver infection")]
  ],
  # Jamie Little — Season 5 → Season 6
  143 => [
    ["\"Rise Above\" episode (Season 5, 2016)",
     "\"Rise Above\" episode (Season 6, 2016)"]
  ],
  # Jaclyn McCaffrey — multiple
  138 => [
    ["Jaclyn McCaffrey (also known as Jaclyn Horvath) is a wilderness therapy professional from Mesa, Arizona. She appeared on Naked and Afraid in four episodes between 2013 and 2014, including the",
     "Jaclyn McCaffrey is a " + cite("https://www.imdb.com/name/nm6659609/", "wildlife educator and primitive-skills teacher from Mesa, Arizona") + ". She appeared on the"]
  ]
}

edited = 0
missed = []
EDITS.each do |sid, replacements|
  s = Survivor.find_by(id: sid)
  next unless s
  before = s.bio.to_s; after = before.dup; applied = false
  replacements.each do |find, replace|
    if after.include?(find); after = after.sub(find, replace); applied = true; end
  end
  if applied; s.update!(bio: normalize(after)); edited += 1; puts "  E #{s.full_name}"
  else; missed << "#{s.full_name} (id=#{sid})"; end
end
puts "→ #{edited} edits"
missed.each { |m| puts "  ! #{m}" }
