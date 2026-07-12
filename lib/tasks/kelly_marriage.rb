# Update Jenny Kelly (id=154) and Steven Kelly (id=327) bios to reflect
# their marriage. Also fix Jenny's bio still using her former name.

# --- Jenny Kelly (id=154) ---
jenny = Survivor.find(154)
before_j = jenny.bio.dup

# Fix opening name
jenny.bio = jenny.bio.sub("Jennifer Pearce is a", "Jenny Kelly is a")

# Prepend a lead sentence noting she's married to Steven Kelly.
if !jenny.bio.include?("Steven Kelly")
  jenny.bio = jenny.bio.sub(
    %q(Jenny Kelly is a Naked and Afraid survivalist),
    %q(Jenny Kelly is a Naked and Afraid survivalist married to fellow survivalist Steven Kelly)
  )
end

if jenny.bio != before_j
  jenny.save!
  puts "  E Jenny Kelly"
else
  puts "  ! Jenny Kelly (no change)"
end

# --- Steven Kelly (id=327) ---
steven = Survivor.find(327)
before_s = steven.bio.dup

# Append a sentence noting his marriage
if !steven.bio.include?("Jenny Kelly")
  steven.bio = steven.bio.rstrip
  steven.bio += " He is married to fellow Naked and Afraid survivalist Jenny Kelly."
end

if steven.bio != before_s
  steven.save!
  puts "  E Steven Kelly"
else
  puts "  ! Steven Kelly (no change)"
end
