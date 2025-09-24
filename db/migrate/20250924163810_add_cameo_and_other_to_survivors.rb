class AddCameoAndOtherToSurvivors < ActiveRecord::Migration[8.0]
  def change
    add_column :survivors, :cameo, :string
    add_column :survivors, :other, :string
  end
end
