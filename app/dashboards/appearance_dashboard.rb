class AppearanceDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id:               Field::Number,
    episode:          Field::BelongsTo,
    survivor:         Field::BelongsTo,
    role:             Field::String,
    starting_psr:     Field::String,
    ending_psr:       Field::String,
    days_lasted:      Field::Number,
    result:           Field::String,
    partner_replacement: Field::Boolean,
    appearance_items: Field::HasMany,
    created_at:       Field::DateTime,
    updated_at:       Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    episode
    survivor
    role
    result
  ].freeze

  SHOW_PAGE_ATTRIBUTES = ATTRIBUTE_TYPES.keys.freeze

  FORM_ATTRIBUTES = %i[
    episode
    survivor
    role
    starting_psr
    ending_psr
    days_lasted
    result
    partner_replacement
  ].freeze

  def display_resource(a)
    s = a.survivor&.full_name || "Survivor"
    e = a.episode&.title || "Episode #{a.episode_id}"
    "#{s} @ #{e}"
  end
end
