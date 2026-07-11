def cite(url, phrase); %Q(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{phrase}</a>); end

s = Survivor.where("full_name ILIKE ?", "gary golding").first
before = s.bio.dup

# Fix the two contradictions:
# 1. XL Season 7 was in Louisiana, not Brazil's Jalapao. Jalapao is his flagship
#    debut with Karra Falkenstein.
# 2. "Dropping out on day 40" refers to XL S7 Louisiana tap-out for illness.
s.bio = s.bio.sub(
  %q(He first appeared on Naked and Afraid in 2018 and competed in season 7 of <a href="/seasons/26">Naked and Afraid XL</a> in Brazil's Jalapao region, dropping out on day 40.),
  %Q(He made his flagship debut in 2018 alongside partner Karra Falkenstein in ) +
    cite("https://calsportsmanmag.com/modern-day-tarzan-l-takes-brazilian-savanna-naked-afraid/", %q(Brazil's Jalapão savanna)) +
    %Q(, and later tapped out of <a href="/seasons/26">Naked and Afraid XL</a> Season 7 (Louisiana, 2021) on day 40 due to illness.)
)

if s.bio != before
  s.save!
  puts "Updated: #{s.full_name}"
else
  puts "No change (find string not matched)"
end
