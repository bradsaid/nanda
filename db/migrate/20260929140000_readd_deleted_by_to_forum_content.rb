class ReaddDeletedByToForumContent < ActiveRecord::Migration[8.0]
  def change
    add_reference :forum_topics, :deleted_by, foreign_key: { to_table: :users }, null: true
    add_reference :forum_posts,  :deleted_by, foreign_key: { to_table: :users }, null: true
  end
end
