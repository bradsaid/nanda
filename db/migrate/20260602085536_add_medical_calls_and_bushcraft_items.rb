class AddMedicalCallsAndBushcraftItems < ActiveRecord::Migration[8.0]
  def change
    create_table :medical_calls do |t|
      t.references :episode,  null: false, foreign_key: true, index: true
      t.references :survivor, foreign_key: true, index: true
      t.string  :reason
      t.boolean :led_to_tapout, null: false, default: false
      t.text    :notes
      t.timestamps
    end

    create_table :bushcraft_items do |t|
      t.references :episode, null: false, foreign_key: true, index: true
      t.integer :builder_ids, array: true, null: false, default: []
      t.string  :item_type
      t.string  :materials
      t.text    :notes
      t.timestamps
    end
    add_index :bushcraft_items, :builder_ids, using: :gin
  end
end
