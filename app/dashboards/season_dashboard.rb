require "administrate/base_dashboard"

class SeasonDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id:                 Field::Number,
    series:             Field::BelongsTo,
    number:             Field::Number,
    continuous_story:   Field::Boolean,  # adjust if your column name differs
    episodes:           Field::HasMany,
    created_at:         Field::DateTime,
    updated_at:         Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    series
    number
    continuous_story
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    series
    number
    continuous_story
    episodes
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    series
    number
    continuous_story
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(season)
    sname = season.series&.name || "Series"
    "Season #{season.number} • #{sname}"
  end
end
