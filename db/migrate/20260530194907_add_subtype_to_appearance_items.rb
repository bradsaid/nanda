class AddSubtypeToAppearanceItems < ActiveRecord::Migration[8.0]
  def change
    add_column :appearance_items, :subtype, :string

    # The previous unique index on (appearance_id, item_id, source) made it
    # impossible to record two variants of the same generic item (e.g. an "elk
    # hide" and a "springbok hide" both under the "hide" item). Replace it with
    # an index that also discriminates on subtype, treating a blank subtype as
    # the canonical generic item.
    remove_index :appearance_items, name: "index_appearance_items_on_appearance_id_and_item_id_and_source"
    add_index :appearance_items,
              "appearance_id, item_id, COALESCE(subtype, ''), source",
              unique: true,
              name: "index_appearance_items_unique_with_subtype"
  end
end
