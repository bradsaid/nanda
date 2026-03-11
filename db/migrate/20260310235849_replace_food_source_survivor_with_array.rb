class ReplaceFoodSourceSurvivorWithArray < ActiveRecord::Migration[8.0]
  def up
    add_column :food_sources, :survivor_ids, :integer, array: true, default: []
    execute "UPDATE food_sources SET survivor_ids = ARRAY[survivor_id::integer] WHERE survivor_id IS NOT NULL"
    remove_foreign_key :food_sources, :survivors
    remove_column :food_sources, :survivor_id
  end

  def down
    add_reference :food_sources, :survivor, foreign_key: true
    execute "UPDATE food_sources SET survivor_id = survivor_ids[1] WHERE array_length(survivor_ids, 1) > 0"
    remove_column :food_sources, :survivor_ids
  end
end
