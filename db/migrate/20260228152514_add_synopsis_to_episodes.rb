class AddSynopsisToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :synopsis, :text
  end
end
