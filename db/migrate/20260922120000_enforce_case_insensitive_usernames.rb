# The existing unique index is on the raw column, so it blocks "alice" twice
# but not "alice" alongside "Alice". Validation catches that, but validation
# cannot win a race between two simultaneous signups — only the database can.
# Usernames deliberately keep their capitalisation, so this is a functional
# index on LOWER(username) rather than a normalising callback.
class EnforceCaseInsensitiveUsernames < ActiveRecord::Migration[8.0]
  def up
    duplicated = select_rows(<<~SQL)
      SELECT LOWER(username), COUNT(*) FROM users
      WHERE username IS NOT NULL
      GROUP BY LOWER(username) HAVING COUNT(*) > 1
    SQL

    if duplicated.any?
      # Better to stop than to pick a winner on someone's behalf.
      raise ActiveRecord::IrreversibleMigration,
            "Usernames differing only by case already exist: " \
            "#{duplicated.map(&:first).join(', ')}. Rename them, then migrate."
    end

    add_index :users, "LOWER(username)",
              unique: true,
              where: "username IS NOT NULL",
              name: "index_users_on_lower_username"
  end

  def down
    remove_index :users, name: "index_users_on_lower_username"
  end
end
