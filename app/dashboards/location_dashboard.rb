class LocationDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id:        Field::Number,
    country:   Field::String,
    region:    Field::String,
    site:      Field::String,
    episodes:  Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[country region site].freeze
  SHOW_PAGE_ATTRIBUTES = ATTRIBUTE_TYPES.keys.freeze
  FORM_ATTRIBUTES = %i[country region site].freeze

  def display_resource(loc)
    [loc.country, loc.region, loc.site].compact_blank.join(" / ").presence || "Location ##{loc.id}"
  end
end
