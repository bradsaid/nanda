# Forum pages were never recorded at all (Forum::BaseController skipped the
# after_action), so there was no way to tell whether anyone was reading the
# forum. They are recorded now, flagged so the existing site figures can keep
# excluding them — both to preserve the meaning of historical numbers and to
# keep user-generated pages out of any ad-facing reporting.
class AddForumFlagToPageViews < ActiveRecord::Migration[8.0]
  def change
    add_column :page_views, :forum, :boolean, default: false, null: false
    add_index  :page_views, [:forum, :created_at], name: "index_page_views_on_forum_and_created_at"
  end
end
