class AddEpisodeTrapIdToFoodSources < ActiveRecord::Migration[8.0]
  def change
    add_reference :food_sources, :episode_trap, null: true, foreign_key: true
  end
end
