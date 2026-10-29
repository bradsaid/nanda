# First-party count of clicks on our affiliate "buy" buttons (see /go/:anchor).
# Deliberately anonymous: no IP, no user agent, no visitor or session id.
class CreateAffiliateClicks < ActiveRecord::Migration[8.0]
  def change
    create_table :affiliate_clicks do |t|
      t.string  :product_anchor,   null: false
      t.string  :product_name
      t.string  :item
      t.string  :store
      t.string  :destination_host
      t.string  :placement
      t.string  :referring_path
      t.boolean :is_mobile, null: false, default: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :affiliate_clicks, :product_anchor
    add_index :affiliate_clicks, :created_at
  end
end
