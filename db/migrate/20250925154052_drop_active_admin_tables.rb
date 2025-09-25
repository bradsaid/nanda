class DropActiveAdminTables < ActiveRecord::Migration[7.1]
  def up
    drop_table :active_admin_comments, if_exists: true
    drop_table :admin_users, if_exists: true
  end

  def down
    # re-create minimal schemas in case you ever rollback
    create_table :admin_users do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps null: false
    end
    add_index :admin_users, :email, unique: true
    add_index :admin_users, :reset_password_token, unique: true

    create_table :active_admin_comments do |t|
      t.string  :namespace
      t.text    :body
      t.references :resource, polymorphic: true
      t.references :author, polymorphic: true
      t.timestamps
    end
  end
end
