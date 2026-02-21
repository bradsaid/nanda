class AddWeightLossToAppearances < ActiveRecord::Migration[8.0]
  def change
    add_column :appearances, :weight_loss, :decimal
  end
end
