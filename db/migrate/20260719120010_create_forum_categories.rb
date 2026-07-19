class CreateForumCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :forum_categories do |t|
      t.string   :name,          null: false
      t.string   :slug,          null: false
      t.text     :description
      t.integer  :position,      null: false, default: 0
      t.boolean  :locked,        null: false, default: false
      t.integer  :topics_count,  null: false, default: 0
      t.datetime :last_topic_at
      t.timestamps
    end

    add_index :forum_categories, :slug,     unique: true
    add_index :forum_categories, :position
  end
end
