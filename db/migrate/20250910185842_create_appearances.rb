class CreateAppearances < ActiveRecord::Migration[7.1]
  def change
    create_table :appearances do |t|
      t.references :survivor, null: false, foreign_key: true
      t.references :episode,  null: false, foreign_key: true
      t.decimal    :starting_psr, precision: 5, scale: 2
      t.decimal    :ending_psr,   precision: 5, scale: 2
      t.integer    :days_lasted
      t.string     :result
      t.string     :role
      t.boolean    :partner_replacement
      t.text       :notes

      t.timestamps
    end

    add_index :appearances, [:survivor_id, :episode_id], unique: true
  end
end
