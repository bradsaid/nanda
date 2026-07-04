class AddIntroToSeasons < ActiveRecord::Migration[8.0]
  def change
    add_column :seasons, :intro, :text
  end
end
