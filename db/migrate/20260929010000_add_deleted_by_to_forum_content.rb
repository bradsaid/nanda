# Removing a topic or post recorded only when, never who. With two moderators
# and authors who can remove their own work, "who removed this?" had no answer.
class AddDeletedByToForumContent < ActiveRecord::Migration[8.0]
  def change
    add_reference :forum_topics, :deleted_by, foreign_key: { to_table: :users }, null: true
    add_reference :forum_posts,  :deleted_by, foreign_key: { to_table: :users }, null: true
  end
end
