class CreateFriendlyIdSlugs < ActiveRecord::Migration[8.0]
  def up
    create_table :friendly_id_slugs do |t|
      t.string   :slug,           null: false
      t.integer  :sluggable_id,   null: false
      t.string   :sluggable_type, limit: 50
      t.string   :scope
      t.datetime :created_at
    end
    add_index :friendly_id_slugs, %i[sluggable_type sluggable_id]
    add_index :friendly_id_slugs, %i[slug sluggable_type]
    add_index :friendly_id_slugs, %i[slug sluggable_type scope],
              unique: true, name: "index_friendly_id_slugs_unique"

    # History only records a slug when a record is next saved, so without this
    # the *current* slug of every existing survivor would be lost the first
    # time one of them is renamed.
    execute <<~SQL.squish
      INSERT INTO friendly_id_slugs (slug, sluggable_id, sluggable_type, created_at)
      SELECT slug, id, 'Survivor', NOW()
        FROM survivors
       WHERE slug IS NOT NULL AND slug <> ''
    SQL
  end

  def down
    drop_table :friendly_id_slugs
  end
end
