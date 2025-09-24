
class DropUniqBroughtPerAppearanceIndex < ActiveRecord::Migration[7.1]
  def up
    remove_index :appearance_items, name: "uniq_brought_per_appearance"
  end

  def down
    # restore if needed
    add_index :appearance_items, :appearance_id,
              unique: true,
              where: "source = 'brought'",
              name: "uniq_brought_per_appearance"
  end
end
