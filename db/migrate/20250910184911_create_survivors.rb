class CreateSurvivors < ActiveRecord::Migration[7.1]
  def change
    create_table :survivors do |t|
      t.string :full_name, null: false
      t.text   :bio
      t.string :instagram
      t.string :facebook
      t.string :youtube
      t.string :website
      t.string :onlyfans
      t.string :merch

      t.timestamps
    end

    add_index :survivors, :full_name, unique: true
  end
end
