# Smooth Jenny Kelly's bio: move the marriage sentence to the end so
# "who appeared" attaches to Jenny, not Steven.
jenny = Survivor.find(154)
before = jenny.bio.dup

# Remove the mid-sentence "married to fellow survivalist Steven Kelly"
jenny.bio = jenny.bio.sub(
  "Jenny Kelly is a Naked and Afraid survivalist married to fellow survivalist Steven Kelly who appeared",
  "Jenny Kelly is a Naked and Afraid survivalist who appeared"
)

# Append marriage sentence at the end (before the extd sentinel if present)
sentinel = "<!-- extd:v1 -->"
marriage = " She is married to fellow Naked and Afraid survivalist Steven Kelly."
if jenny.bio.include?(sentinel)
  jenny.bio = jenny.bio.sub(sentinel, marriage + "\n" + sentinel)
else
  jenny.bio = jenny.bio.rstrip + marriage
end

if jenny.bio != before
  jenny.save!
  puts "Updated: #{jenny.full_name}"
else
  puts "No change"
end
