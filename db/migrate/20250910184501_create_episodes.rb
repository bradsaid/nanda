class CreateEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :episodes do |t|
      t.references :season, null: false, foreign_key: true
      t.integer :number_in_season
      t.string :title
      t.date :air_date
      t.integer :scheduled_days
      t.string :participant_arrangement
      t.string :type_modifiers
      t.references :location, null: false, foreign_key: true
      t.text :notes

      t.timestamps
    end

    add_index :episodes, [:season_id, :number_in_season], unique: true

  end

end
