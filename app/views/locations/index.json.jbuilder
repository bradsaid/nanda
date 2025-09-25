json.array! @locations.select { |l| l.latitude && l.longitude } do |l|
  json.extract! l, :id, :latitude, :longitude
  json.name    l.site.presence || l.region.presence || l.country
  json.address l.full_address
  json.episodes_count l.try(:episodes_count).to_i
  json.episodes_url episodes_path(location_id: l.id)
end