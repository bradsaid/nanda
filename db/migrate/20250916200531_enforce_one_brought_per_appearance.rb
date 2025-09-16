class EnforceOneBroughtPerAppearance < ActiveRecord::Migration[8.0]
  def change
    # one 'brought' per appearance
    add_index :appearance_items,
              :appearance_id,
              unique: true,
              where: "source = 'brought'",
              name: "uniq_brought_per_appearance"
  end
end