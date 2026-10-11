# config/initializers/geocoder.rb
Geocoder.configure(
  lookup: :nominatim,
  timeout: 5,
  units: :km,
  http_headers: { "User-Agent" => "nakedandafraid.app (contact: brad@nakedandafraidfan.com)" }
)
