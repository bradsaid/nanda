class AddForumFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.string   :username
      t.datetime :email_verified_at
      t.datetime :banned_at
      t.text     :ban_reason
      t.integer  :posts_count, default: 0, null: false
      t.datetime :last_seen_at
    end

    add_index :users, :username, unique: true, where: "username IS NOT NULL"
    add_index :users, :banned_at
  end
end
