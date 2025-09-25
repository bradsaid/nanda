require "administrate/base_dashboard"

class EpisodeDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id:                Field::Number,
    season:            Field::BelongsTo,
    location:          Field::BelongsTo,
    number_in_season:  Field::Number,
    title:             Field::String,
    air_date:          Field::DateTime,
    scheduled_days:    Field::String,
    notes:             Field::Text,
    appearances:       Field::HasMany,
    created_at:        Field::DateTime,
    updated_at:        Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    title
    season
    number_in_season
    air_date
    location
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    season
    number_in_season
    air_date
    location
    scheduled_days
    notes
    appearances
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    season
    location
    title
    number_in_season
    air_date
    scheduled_days
    notes
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(ep)
    ep.title.presence || "Episode ##{ep.number_in_season || ep.id}"
  end
end
