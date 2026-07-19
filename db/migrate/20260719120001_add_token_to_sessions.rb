class AddTokenToSessions < ActiveRecord::Migration[8.0]
  def change
    change_table :sessions do |t|
      t.string   :token
      t.datetime :remembered_until
    end

    add_index :sessions, :token, unique: true, where: "token IS NOT NULL"
    add_index :sessions, :user_id unless index_exists?(:sessions, :user_id)
  end
end
