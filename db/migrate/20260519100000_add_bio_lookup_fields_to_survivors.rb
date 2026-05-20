class AddBioLookupFieldsToSurvivors < ActiveRecord::Migration[8.0]
  def change
    add_column :survivors, :bio_source_url, :string
    add_column :survivors, :bio_lookup_status, :string, default: "pending", null: false
    add_column :survivors, :bio_checked_at, :datetime
    add_index  :survivors, :bio_lookup_status
  end
end
