class AddAnalyticsFieldsToPageViews < ActiveRecord::Migration[8.0]
  def change
    add_column :page_views, :country, :string
    add_column :page_views, :city, :string
    add_column :page_views, :browser, :string
    add_column :page_views, :os, :string
    add_column :page_views, :device_type, :string
    add_column :page_views, :session_id, :string
    add_column :page_views, :duration_seconds, :integer
    add_column :page_views, :referrer_domain, :string
    add_index :page_views, :session_id
  end
end
