class CreateForumTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :forum_topics do |t|
      t.references :forum_category, null: false, foreign_key: true
      t.references :user,           null: false, foreign_key: true
      t.string   :title,             null: false
      t.string   :slug,              null: false
      t.boolean  :pinned,            null: false, default: false
      t.boolean  :locked,            null: false, default: false
      t.integer  :posts_count,       null: false, default: 0
      t.integer  :views_count,       null: false, default: 0
      t.datetime :last_post_at
      t.references :last_post_user,  foreign_key: { to_table: :users }
      t.datetime :deleted_at
      t.timestamps
    end

    # Slugs are scoped per-category so two categories can each have a "Hi" topic.
    add_index :forum_topics, [:forum_category_id, :slug], unique: true
    add_index :forum_topics, :last_post_at
    add_index :forum_topics, :pinned
    add_index :forum_topics, :deleted_at
  end
end
