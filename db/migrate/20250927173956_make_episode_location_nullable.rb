# db/migrate/20250927170000_make_episode_location_nullable.rb
class MakeEpisodeLocationNullable < ActiveRecord::Migration[7.1]
  def change
    change_column_null :episodes, :location_id, true
  end
end
