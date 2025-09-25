require "administrate/base_dashboard"

class SeriesDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id:        Field::Number,
    name:      Field::String,
    seasons:   Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    name
    seasons
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    seasons
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    name
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(series)
    series.name.presence || "Series ##{series.id}"
  end
end
