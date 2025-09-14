# app/models/location.rb
class Location < ApplicationRecord
  has_many :episodes, dependent: :restrict_with_exception

  def full_address
    [site, region, country].compact_blank.join(", ")
  end

  geocoded_by :full_address do |loc, results|
    if (h = results.first)
      loc.latitude  = h.latitude
      loc.longitude = h.longitude
    end
  end

  before_validation :normalize_fields
  after_validation  :geocode, if: :should_geocode?

  private

  def normalize_fields
    self.country = country.to_s.strip.presence
    self.region  = region.to_s.strip.presence
    self.site    = site.to_s.strip.presence
  end

  def should_geocode?
    latitude.blank? || longitude.blank? ||
      saved_change_to_country? || saved_change_to_region? || saved_change_to_site?
  end
end
