class CreateAppearanceItems < ActiveRecord::Migration[7.1]
  def change
    create_table :appearance_items do |t|
      t.references :appearance, null: false, foreign_key: true
      t.references :item,       null: false, foreign_key: true
      t.string  :source, null: false
      t.integer :quantity, null: false, default: 1
      t.text    :notes
      t.timestamps
    end

    add_index :appearance_items, [:appearance_id, :item_id, :source], unique: true
  end
end
