require "administrate/base_dashboard"

class SurvivorDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id:          Field::Number,
    first_name:  Field::String,
    last_name:   Field::String,
    full_name:   Field::String,
    bio:         Field::Text,
    avatar:      Field::ActiveStorage,   # requires administrate-field-active_storage (optional)
    appearances: Field::HasMany,
    # episodes through appearances aren't auto-wired as a field, you can add a virtual field if desired
    created_at:  Field::DateTime,
    updated_at:  Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    full_name
    last_name
    appearances
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    full_name
    first_name
    last_name
    bio
    appearances
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    first_name
    last_name
    full_name
    bio
    avatar
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(survivor)
    survivor.full_name.presence ||
      [survivor.first_name, survivor.last_name].compact.join(" ").presence ||
      "Survivor ##{survivor.id}"
  end
end
