class AddQuantityToFoodSources < ActiveRecord::Migration[8.0]
  def change
    add_column :food_sources, :quantity, :integer, default: 1, null: false
  end
end
