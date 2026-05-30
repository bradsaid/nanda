class AllowNullQuantityOnFoodSources < ActiveRecord::Migration[8.0]
  def change
    change_column_null :food_sources, :quantity, true
    change_column_default :food_sources, :quantity, from: 1, to: nil
  end
end
