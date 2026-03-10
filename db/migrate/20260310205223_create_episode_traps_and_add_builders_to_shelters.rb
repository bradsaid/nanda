class CreateEpisodeTrapsAndAddBuildersToShelters < ActiveRecord::Migration[8.0]
  def change
    create_table :episode_traps do |t|
      t.references :episode, null: false, foreign_key: true
      t.string :trap_type, null: false
      t.string :result
      t.integer :builder_ids, array: true, default: []
      t.text :notes
      t.timestamps
    end

    add_column :episode_shelters, :builder_ids, :integer, array: true, default: []
  end
end
