# One-off: replace em-dash punctuation in existing survivor bios with more
# natural equivalents. Em-dashes read as an AI-generation signal for content
# review, so we normalize them. Idempotent: safe to run twice.
count = 0
Survivor.where("bio LIKE '% — %'").find_each do |s|
  new_bio = s.bio.to_s
    .gsub(" — neither of whom spoke the other's language — ", " (neither of whom spoke the other's language) ")
    .gsub(" — the first amputee cast on Discovery's", ", the first amputee cast on Discovery's")
    .gsub(" — the first time the show featured siblings.", ". It was the first time the show featured siblings.")
    .gsub(" — ", ", ")
  next if new_bio == s.bio
  s.update!(bio: new_bio)
  count += 1
  puts "  ✓ #{s.full_name}"
end
puts ""
puts "Cleaned #{count} bios; remaining with em-dash: #{Survivor.where("bio LIKE '% — %'").count}"
