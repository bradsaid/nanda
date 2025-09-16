class AddAvatarUrlToSurvivors < ActiveRecord::Migration[8.0]
  def change
    add_column :survivors, :avatar_url, :string
  end
end
