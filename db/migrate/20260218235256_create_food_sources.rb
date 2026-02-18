class CreateFoodSources < ActiveRecord::Migration[8.0]
  def change
    create_table :food_sources do |t|
      t.references :episode, null: false, foreign_key: true
      t.references :survivor, null: true, foreign_key: true
      t.string :category, null: false
      t.string :name, null: false
      t.string :method
      t.string :tools_used
      t.text :notes

      t.timestamps
    end

    add_index :food_sources, [:name, :episode_id]
  end
end
