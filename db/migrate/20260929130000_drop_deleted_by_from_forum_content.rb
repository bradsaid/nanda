class DropDeletedByFromForumContent < ActiveRecord::Migration[8.0]
  def change
    remove_reference :forum_posts,  :deleted_by, foreign_key: { to_table: :users }
    remove_reference :forum_topics, :deleted_by, foreign_key: { to_table: :users }
  end
end
