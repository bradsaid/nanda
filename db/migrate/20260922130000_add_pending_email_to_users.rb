# An email change is only applied once the new address has been confirmed from
# a link sent to it. Until then it lives here, so a typo cannot strand someone
# on an address they do not own.
class AddPendingEmailToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :pending_email_address, :string
    add_index  :users, "LOWER(pending_email_address)",
               where: "pending_email_address IS NOT NULL",
               name: "index_users_on_lower_pending_email"
  end
end
