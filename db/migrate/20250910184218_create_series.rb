class CreateSeries < ActiveRecord::Migration[8.0]
  def change
    create_table :series do |t|
      t.string :name

      t.timestamps
    end
    add_index :series, :name, unique: true
  end
end
