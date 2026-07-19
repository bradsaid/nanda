class CreateForumReports < ActiveRecord::Migration[8.0]
  def change
    create_table :forum_reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :reportable, polymorphic: true, null: false
      t.integer  :reason,     null: false, default: 0
      t.integer  :status,     null: false, default: 0
      t.text     :notes
      t.references :handled_by, foreign_key: { to_table: :users }
      t.datetime :handled_at
      t.timestamps
    end

    add_index :forum_reports, :status
    add_index :forum_reports, [:reportable_type, :reportable_id]
  end
end
