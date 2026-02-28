class CreatePageViews < ActiveRecord::Migration[8.0]
  def change
    create_table :page_views do |t|
      t.string :path
      t.string :controller_name
      t.string :action_name
      t.string :method
      t.string :ip_address
      t.string :user_agent
      t.string :referrer
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :page_views, :path
    add_index :page_views, :created_at
    add_index :page_views, :controller_name
  end
end
