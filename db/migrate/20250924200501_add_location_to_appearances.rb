class AddLocationToAppearances < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:appearances, :location_id)
      add_reference :appearances, :location, null: true, foreign_key: true, index: true
    end
  end
end