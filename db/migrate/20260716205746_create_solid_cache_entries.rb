class CreateSolidCacheEntries < ActiveRecord::Migration[8.0]
  def change
    # Solid Cache's schema is in db/cache_schema.rb, but the cache role uses
    # `database_tasks: false` so `db:prepare` never loads it. Since production
    # runs cache off the primary DB, create the table via a regular migration.
    return if table_exists?(:solid_cache_entries)

    create_table :solid_cache_entries do |t|
      t.binary   :key,       limit: 1024, null: false
      t.binary   :value,     limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.integer  :key_hash,  limit: 8, null: false
      t.integer  :byte_size, limit: 4, null: false
    end

    add_index :solid_cache_entries, :byte_size
    add_index :solid_cache_entries, [:key_hash, :byte_size]
    add_index :solid_cache_entries, :key_hash, unique: true
  end
end
