class CreateForumSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :forum_subscriptions do |t|
      t.references :user,        null: false, foreign_key: true
      t.references :forum_topic, null: false, foreign_key: true
      t.timestamps
    end

    add_index :forum_subscriptions, [:user_id, :forum_topic_id], unique: true
  end
end
