class AddSlugToSurvivors < ActiveRecord::Migration[8.0]
  def change
    add_column :survivors, :slug, :string
    add_index :survivors, :slug, unique: true
  end
end
