# Batch 2, wave 10 partial (survivors 127-133).
def normalize_whitespace(s); s.gsub(/[ \t]{2,}/, " ").gsub(/\s+([.,!?;:])/, '\1').strip; end
def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

EDITS = {
  # Fernando Calderon — date correction
  117 => [
    ["He debuted on the show in 2013 during a 21-day challenge in Malaysia,",
     "He debuted on the show in " + cite("https://www.toacorn.com/articles/fire-captain-gets-naked-and-afraid-on-television/", "2014 during a 21-day challenge in Malaysia (filmed in 2013)") + ","]
  ],

  # Gary Golding — XL S7 location fix
  122 => [
    ["competed in season 7 of Naked and Afraid XL in Brazil's Jalapao region, dropping out on day 40",
     "competed in season 7 of Naked and Afraid XL in " + cite("https://thecinemaholic.com/where-is-naked-and-afraid-xl-season-7-filmed/", "Louisiana's Atchafalaya Basin") + ", tapping out on day 40"]
  ],

  # Gabrielle Balassone — challenge count + solo run framing
  121 => [
    ["completed five challenges across Naked and Afraid and Naked and Afraid XL since 2017, including two solo runs.",
     "completed " + cite("https://www.baltimoresun.com/maryland/carroll/news/cc-naked-afraid-again-20180321-story.html", "six challenges across Naked and Afraid and Naked and Afraid XL since 2017") + ", twice finishing as the last survivor standing after her partners tapped out early."]
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
  if applied; s.update!(bio: normalize_whitespace(after)); edited += 1; puts "  E #{s.full_name}"
  else; missed << "#{s.full_name} (id=#{sid})"; end
end
puts "→ Applied #{edited} bio edits"
missed.each { |m| puts "  ! #{m}" } if missed.any?
