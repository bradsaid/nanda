class ItemDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id:        Field::Number,
    name:      Field::String,
    item_type: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[name item_type].freeze
  SHOW_PAGE_ATTRIBUTES  = ATTRIBUTE_TYPES.keys.freeze
  FORM_ATTRIBUTES       = %i[name item_type].freeze
end
