class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :country
      t.string :region
      t.string :site

      t.timestamps
    end

    add_index :locations, [:country, :region, :site]

  end
end
