# Follow-up to batch1_bio_edits.rb. Handles the edits that missed the first
# time (due to HTML tags) plus the remaining days-language cleanups now that
# the bios are in a known intermediate state.

def normalize_whitespace(s)
  s.gsub(/[ \t]{2,}/, " ")
   .gsub(/\s+([.,!?;:])/, '\1')
   .gsub(/\n{3,}/, "\n\n")
   .gsub(/,\s*\.\Z/, ".")
   .gsub(/,\s*\z/, ".")
   .strip
end

EDITS = {
  # Aaron Phillips — replace "surviving 21 days" performance framing
  2 => [
    ["surviving 21 days in the Belize jungle and discovering a bot fly larva in his groin",
     "taking on the 21-day Belize jungle challenge and discovering a bot fly larva in his groin"]
  ],

  # Afften DeShazer — clean the day-count follow-up we introduced last run
  6 => [
    ["tapping out on day 7 and leaving Zack to complete the final 14 days of the 21-day challenge alone",
     "tapping out early and leaving Zack to complete the 21-day challenge alone"]
  ],

  # Alexa Towersey — drop specific-day counts (21 days, 35 days)
  10 => [
    ["She survived 21 days in the Colombian jungle on Naked and Afraid, then endured 35 days in the South African desert on <a href=\"/seasons\">Naked and Afraid: Apocalypse</a> and represented Australia on <a href=\"/seasons\">Naked and Afraid: Global Showdown</a>.",
     "She has taken on the Colombian jungle on Naked and Afraid, the South African desert on <a href=\"/seasons\">Naked and Afraid: Apocalypse</a>, and represented Australia on <a href=\"/seasons\">Naked and Afraid: Global Showdown</a>."]
  ],

  # Alyssa Ballestero — HTML-aware find-string
  15 => [
    ["and went on to become a regular on <a href=\"/seasons\">Naked and Afraid XL</a>, including the 40-day South Africa challenge.",
     "and later competed on <a href=\"/seasons\">Naked and Afraid XL</a> Season 2's 40-day South Africa challenge."]
  ],

  # Amber Hargrove — drop the "60-day" specific
  20 => [
    ["including a roughly 60-day stretch in the Peruvian Amazon for <a href=\"/seasons\">Naked and Afraid XL</a>.",
     "including the Peruvian Amazon leg of <a href=\"/seasons\">Naked and Afraid XL</a>."]
  ],

  # Amy Zindler — drop "attempting 21 days"
  22 => [
    ["attempting 21 days with partner Tray Heinke in the punishing landscape",
     "taking on the challenge with partner Tray Heinke in the punishing landscape"]
  ],

  # Andrea Lopez — drop "completing the full 21 days"
  25 => [
    ["completing the full 21 days while she worked through PTSD from her law-enforcement years",
     "completing the challenge while she worked through PTSD from her law-enforcement years"]
  ],

  # Ann Alford — drop "attempting 21 days"
  32 => [
    ["attempting 21 days with a former Marine sniper in a Colombian swamp",
     "taking on the challenge with a former Marine sniper in a Colombian swamp"]
  ],

  # Annie Foley — fix the trailing comma from earlier days-sweep collateral
  34 => [
    ['braving the jungles of Belize,',
     'braving the jungles of Belize.']
  ],

  # Amanda Standley — HTML-aware Texan wilderness guide rewrite
  499 => [
    ["Amanda Standley is a survivalist who appeared on <a href=\"/seasons\">Naked and Afraid</a> Season 19 (2026) on Discovery Channel. Publicly available biographical details about her background are limited.",
     "Amanda Standley is a Texan wilderness guide who appeared on <a href=\"/seasons\">Naked and Afraid</a> Season 19 (2026), partnering with South African ranger Andries Prinsloo on a 21-day challenge in the Thai jungle."]
  ],

  # Beverly Reynolds — HTML-aware; drop the unsourced S12E6 credit
  42 => [
    ["in episodes including <a href=\"/episodes/123\">Naked and Afraid S12E6 \"A Tangled Web in Texas\"</a> and <a href=\"/episodes/132\">Naked and Afraid S13E4 \"USA vs. World\"</a>",
     "in <a href=\"/episodes/132\">Naked and Afraid S13E4 \"USA vs. World\"</a>"]
  ],

  # Billy Berger — drop "surviving 21 days" performance framing
  44 => [
    ["surviving 21 days in the swamps of Louisiana with partner Ky Furneaux",
     "taking on the swamps of Louisiana with partner Ky Furneaux"]
  ]
}

edited = 0
missed = []
EDITS.each do |sid, replacements|
  s = Survivor.find_by(id: sid)
  unless s
    missed << "id=#{sid} not found"
    next
  end
  before = s.bio.to_s
  after = before.dup
  applied_any = false
  replacements.each do |find, replace|
    if after.include?(find)
      after = after.sub(find, replace)
      applied_any = true
    end
  end
  if applied_any && after != before
    s.update!(bio: normalize_whitespace(after))
    edited += 1
    puts "  E #{s.full_name}"
  elsif !applied_any
    missed << "#{s.full_name} (id=#{sid}): none of the find-strings matched"
  end
end
puts "→ Applied #{edited} follow-up edits"
puts ""
missed.each { |m| puts "  ! #{m}" } if missed.any?
