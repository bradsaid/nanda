# Julio Castano prod bio differs from local — apply prod-specific fix
s = Survivor.find(177)
before = s.bio.dup
s.bio = s.bio.sub(
  %q(appeared in four episodes during 2016-2017, including <em>"Into the Wild"</em>, <a href="/episodes/47">Naked and Afraid S6E9 "The Danger Within"</a>),
  %q(appeared in <a href="/episodes/47">Naked and Afraid S6E9 "The Danger Within"</a> (2016))
)
if s.bio != before
  s.save!
  puts "Updated: #{s.full_name}"
else
  puts "No change (find string not matched)"
end
