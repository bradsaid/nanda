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

  # Runs in after_validation, i.e. *before* the save, so the pending change is
  # what matters. saved_change_to_*? describes the previous save and was
  # therefore false here, which meant moving a location (new site, region or
  # country) never refreshed its coordinates once it had any.
  #
  # Two guards keep this from being over-eager: a brand-new record that already
  # carries coordinates keeps them (importers supply known-good ones), and so
  # does a save that sets the coordinates by hand alongside the address.
  def should_geocode?
    return true if latitude.blank? || longitude.blank?
    return false if new_record?
    return false if will_save_change_to_latitude? || will_save_change_to_longitude?

    will_save_change_to_country? || will_save_change_to_region? || will_save_change_to_site?
  end
end
