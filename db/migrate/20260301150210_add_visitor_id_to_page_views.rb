class AddVisitorIdToPageViews < ActiveRecord::Migration[8.0]
  def change
    add_column :page_views, :visitor_id, :string
    add_index :page_views, :visitor_id
  end
end
