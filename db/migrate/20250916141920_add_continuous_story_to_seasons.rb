class AddContinuousStoryToSeasons < ActiveRecord::Migration[8.0]
  def change
    add_column :seasons, :continuous_story, :boolean, default: false, null: false
    add_index  :seasons, :continuous_story
  end
end