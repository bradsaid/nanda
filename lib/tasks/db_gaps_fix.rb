# Fill in DB gaps identified during bio verification.

def add_apps(survivor_id, episode_ids, label)
  s = Survivor.find(survivor_id)
  added = 0
  episode_ids.each do |eid|
    ep = Episode.find(eid)
    a = s.appearances.where(episode_id: eid).first_or_initialize
    if a.new_record?
      a.save!
      added += 1
      puts "  + #{s.full_name} → #{ep.title}"
    end
  end
  puts "→ #{label}: #{added} new appearances"
end

# XL S10 episode IDs (Colombia, 2024)
XL_S10 = { 1 => 269, 2 => 270, 3 => 271, 4 => 272, 5 => 273, 6 => 274, 7 => 275, 8 => 276 }

# Kaiela Hobart (id=183) — XL S10 E1-E6 per Seattle Times / IMDb
puts "== Kaiela Hobart XL S10 =="
add_apps(183, XL_S10.values_at(1, 2, 3, 4, 5, 6), "Kaiela Hobart XL S10 E1-E6")

# Lynsey McCarver (id=226) — XL S10 E1-E7 per Spokesman-Review / IMDb
puts "== Lynsey McCarver XL S10 =="
add_apps(226, XL_S10.values_at(1, 2, 3, 4, 5, 6, 7), "Lynsey McCarver XL S10 E1-E7")

# Create S10E20 "Stalked on the Savannah Part 2" (Brazil, 2019-06-30) if missing
puts "== Wes Adams — create S10E20 if missing =="
s10 = Season.joins(:series).where(number: 10).where("series.name NOT LIKE ?", "%XL%").first
ep20 = Episode.where(season: s10, number_in_season: 20).first
if ep20
  puts "  S10E20 already exists: #{ep20.title.inspect}"
else
  ep19 = Episode.find(98)  # template for series/location
  ep20 = Episode.create!(
    season: s10,
    number_in_season: 20,
    title: "Stalked on the Savannah Part 2",
    air_date: "2019-06-30",
    location_id: ep19.location_id
  )
  puts "  Created S10E20: id=#{ep20.id} #{ep20.title}"
end

puts "== Wes Adams S10E19 + S10E20 =="
add_apps(356, [98, ep20.id], "Wes Adams S10E19-20")

# Sarah Danser (id=306) — XL S6 SA "Valley of the Banished" 2020 per NBC obit + IMDb
puts "== Sarah Danser XL S6 =="
XL_S6 = (238..248).to_a  # E1-E11
add_apps(306, XL_S6, "Sarah Danser XL S6 E1-E11")
