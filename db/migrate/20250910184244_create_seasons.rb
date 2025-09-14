class CreateSeasons < ActiveRecord::Migration[8.0]
  def change
    create_table :seasons do |t|
      t.references :series, null: false, foreign_key: true
      t.integer :number
      t.integer :year

      t.timestamps
    end

    add_index :seasons, [:series_id, :number], unique: true
    
  end
end
