# One-off: batch 1 verification cleanups.
#   Part A — global sweep of extender-generated days language.
#   Part B — per-survivor batch-1 edits (fact corrections + days language
#            in hand-written batch-1 bios).
#   Part C — DB rename: "Beau Martin" → "Beau Martino"
# Idempotent by construction: each edit uses String#sub with an exact match,
# so re-running skips already-applied edits.

def normalize_whitespace(s)
  s.gsub(/[ \t]{2,}/, " ")
   .gsub(/\s+([.,!?;:])/, '\1')
   .gsub(/\n{3,}/, "\n\n")
   .strip
end

# --- Part A. Extender-generated days-language sweep -----------------------
DAY_STRIP_PATTERNS = [
  / [A-Z][a-z]+ logged \d+ days in the wild on that run\./,
  / Across every appearance combined, [A-Z][a-z]+ has logged \d+ days on-camera in the wild\./,
  / They have logged a combined \d+ days on the show\./,
  / The run closed with a final PSR of [\d.]+ over \d+ days on the ground\./,
  / The run lasted \d+ days on the ground\./,
  /, with a combined \d+ days logged in the wild across every appearance/,
]

days_stripped = 0
Survivor.where("bio LIKE '%days%'").find_each do |s|
  before = s.bio.to_s
  after  = before.dup
  DAY_STRIP_PATTERNS.each { |p| after = after.gsub(p, "") }
  after  = normalize_whitespace(after)
  next if before == after
  s.update!(bio: after)
  days_stripped += 1
  puts "  D #{s.full_name}"
end
puts "→ Extender days-language stripped from #{days_stripped} bios"
puts ""

# --- Part B. Per-survivor batch-1 edits ------------------------------------
# Each entry: id => [[find, replace], ...]
EDITS = {
  # 1. Alison Teal — Trash Island phrasing
  13 => [
    ['marooned on a remote Maldivian island where she famously discovered "Trash Island."',
     "marooned on a remote Maldivian island where she famously helped expose the country's plastic pollution crisis."]
  ],

  # 2. Afften DeShazer — correct the "14 miles" error and remove day counts
  6 => [
    [", tapping out a week before the final 14-mile extraction hike.",
     ", tapping out early and leaving Zack to complete the 21-day challenge alone."],
    ["Afften DeShazer is a fitness model, actress and real estate agent",
     "Afften DeShazer is a fitness model and real estate agent"]
  ],

  # 3. Adam Young — soften Melbourne/1985/wild-game guide
  5 => [
    ["Adam Young is an outdoorsman and wild game guide from Melbourne, Florida, born in 1985.",
     "Adam Young is a Florida-based outdoorsman and freshwater fishing content creator."]
  ],

  # 4. Aaron Phillips — bot fly in groin (also remove "surviving 21 days")
  2 => [
    ["surviving 21 days in the Belize jungle and discovering a bot fly larva in his leg along the way",
     "taking on the 21-day Belize jungle challenge and discovering a bot fly larva in his groin along the way"]
  ],

  # 5. Alexandra Martin — brand name + soften herbalism/primitive skills
  11 => [
    ["runs the Barefoot &amp; Breathing platform, blending breathwork, herbalism, yoga and primitive skills.",
     "runs the Barefoot and Breathing platform, blending breathwork, yoga, and nature-connection retreats."],
    ["runs the Barefoot & Breathing platform, blending breathwork, herbalism, yoga and primitive skills.",
     "runs the Barefoot and Breathing platform, blending breathwork, yoga, and nature-connection retreats."]
  ],

  # 6. AK Kaye — remove motivational speaker, rephrase Native American origin,
  #    add sheriff's deputy role + TOPS A-Klub factoid
  7 => [
    ['Amanda "AK" Kaye is an Alabama-based survival instructor, knife designer and motivational speaker who grew up hunting and studying Native American primitive skills.',
     'Amanda "AK" Kaye is an Alabama-based survival instructor, knife designer and Autauga County Sheriff\'s Deputy who grew up hunting and learning primitive skills through her family\'s living-history reenactments at Fort Toulouse. Her TOPS A-Klub was the first TOPS blade designed by a woman.']
  ],

  # 7. Allison Frueh — 1000-day tree climb is ongoing (this is a fitness
  #    streak, NOT survival days — keep the 1,000 number)
  14 => [
    ["famously climbed a tree every day for 1,000 days",
     "is on an ongoing streak to climb a tree every day for 1,000 days"]
  ],

  # 8. Amber Hargrove — six → seven seasons; drop the 60-day XL specific
  20 => [
    ["She has appeared across six seasons of the franchise in environments from the Florida Everglades to Namibia, including a roughly 60-day stretch in the Peruvian Amazon for <a href=\"/seasons\">Naked and Afraid XL</a>.",
     "She has appeared across seven seasons of the franchise in environments from the Florida Everglades to Namibia, including the Peruvian Amazon leg of <a href=\"/seasons\">Naked and Afraid XL</a>."]
  ],

  # 9. Alyssa Ballestero — HTML-aware find-string
  15 => [
    ['and went on to become a regular on <a href="/seasons">Naked and Afraid XL</a>, including the 40-day South Africa challenge.',
     'and later competed on <a href="/seasons">Naked and Afraid XL</a> Season 2\'s 40-day South Africa challenge.']
  ],

  # 10. Amanda Standley — HTML-aware find-string, adds Texan wilderness guide
  499 => [
    ["Amanda Standley is a survivalist who appeared on <a href=\"/seasons\">Naked and Afraid</a> Season 19 (2026) on Discovery Channel. Publicly available biographical details about her background are limited.",
     "Amanda Standley is a Texan wilderness guide who appeared on <a href=\"/seasons\">Naked and Afraid</a> Season 19 (2026), partnering with South African ranger Andries Prinsloo on a 21-day challenge in the Thai jungle."]
  ],

  # 11. Andrew Bishop — soften "mountaineering partner"
  26 => [
    ["taking shelter with a mountaineering partner",
     "taking shelter with his partner Rizza Bagan"]
  ],

  # 12. Angela Narduzzi — Darren → Darrin Reay
  31 => [
    ["pairing with loner survivalist Darren",
     "pairing with loner survivalist Darrin Reay"]
  ],

  # 13. Annie Foley — remove misattributed North Ogden UT origin
  34 => [
    ["Annie Foley is a North Ogden, Utah native who at the time of filming was a farmer's wife, mother of four, and photographer based in Essex, Illinois.",
     "Annie Foley is a farmer's wife, mother of four, and photographer based in Essex, Illinois."]
  ],

  # 17. Ava Holmes — co-founded + remove speech coach + fix episode conflation
  40 => [
    ["Ava J. Holmes is a Seattle-based speech-confidence coach, motivational speaker, and TEDxSeattle 2017 speaker who founded the nonprofit Fashion for Conservation.",
     "Ava J. Holmes is a Seattle-based fashion producer and TEDxSeattle speaker who co-founded the nonprofit Fashion for Conservation in 2012."],
    ['with episodes including "Unsurvivable" and <a href="/episodes/72">Naked and Afraid S9E6 "Thieves in the Night"</a>, where she and partner Steven Townes resorted to hunting bats for protein.',
     'appearing in the Season 9 episode "Unsurvivable" and returning for <a href="/episodes/72">Naked and Afraid S9E6 "Thieves in the Night"</a>, where she and partner Steven Townes resorted to hunting bats for protein.']
  ],

  # 18. Ben Johnson — West Indies → Bahamas
  41 => [
    ["on their way to land in the West Indies",
     "on their way to land in the Bahamas"]
  ],

  # 19. Beverly Reynolds — HTML-aware find-string; drop the unsourced S12E6
  42 => [
    ["in episodes including <a href=\"/episodes/123\">Naked and Afraid S12E6 \"A Tangled Web in Texas\"</a> and <a href=\"/episodes/132\">Naked and Afraid S13E4 \"USA vs. World\"</a>",
     "in <a href=\"/episodes/132\">Naked and Afraid S13E4 \"USA vs. World\"</a>"]
  ],

  # 20. Billy Jennings — partner name + soften Army officer
  45 => [
    ["a former U.S. Army officer who deployed to Afghanistan in 2011-2012",
     "a U.S. military veteran"],
    ["navigating Limpopo, South Africa with partner Sam in",
     "navigating Limpopo, South Africa with partner Samantha \"Sam\" Ray Moore in"]
  ],

  # Additional days-language removals for batch-1 hand-written bios
  # Alexa Towersey — drop "survived 21 days" and "endured 35 days"
  10 => [
    ["She survived 21 days in the Colombian jungle on Naked and Afraid, then endured 35 days in the South African desert on <a href=\"/seasons\">Naked and Afraid: Apocalypse</a> and represented Australia on <a href=\"/seasons\">Naked and Afraid: Global Showdown</a>.",
     "She has taken on the Colombian jungle on Naked and Afraid, the South African desert on <a href=\"/seasons\">Naked and Afraid: Apocalypse</a>, and represented Australia on <a href=\"/seasons\">Naked and Afraid: Global Showdown</a>."]
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

  # Billy Berger — drop "surviving 21 days"
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
puts "→ Applied #{edited} per-survivor edits"
puts ""
missed.each { |m| puts "  ! #{m}" } if missed.any?
puts ""

# --- Part C. DB rename: Beau Martin → Beau Martino -------------------------
beau = Survivor.find_by(full_name: "Beau Martin")
if beau
  beau.full_name = "Beau Martino"
  beau.slug = nil    # friendly_id regenerates the slug on next save
  beau.save!
  puts "→ Renamed 'Beau Martin' → '#{beau.full_name}' (slug now '#{beau.slug}')"
else
  existing = Survivor.find_by(full_name: "Beau Martino")
  puts "→ Beau rename skipped (already '#{existing&.full_name || "not found"}')"
end
