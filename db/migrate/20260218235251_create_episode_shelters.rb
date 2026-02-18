class CreateEpisodeShelters < ActiveRecord::Migration[8.0]
  def change
    create_table :episode_shelters do |t|
      t.references :episode, null: false, foreign_key: true
      t.string :shelter_type
      t.string :materials
      t.text :notes

      t.timestamps
    end
  end
end
