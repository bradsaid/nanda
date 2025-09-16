class AddContinuousStoryToSeries < ActiveRecord::Migration[8.0]
  def change
    add_column :series, :continuous_story, :boolean, null: false, default: false
    add_index  :series, :continuous_story
  end
end