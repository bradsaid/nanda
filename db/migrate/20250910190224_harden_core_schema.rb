class HardenCoreSchema < ActiveRecord::Migration[8.0]
  def change
    # 1) enable citext (safe if already enabled)
    enable_extension "citext" unless extension_enabled?("citext")

    # 2) make case-insensitive unique columns
    change_column :survivors, :full_name, :citext, null: false
    change_column :items,     :name,      :citext, null: false

    # re-create unique indexes to match citext type (drops are no-ops if names differ)
    remove_index :survivors, column: :full_name if index_exists?(:survivors, :full_name)
    add_index    :survivors, :full_name, unique: true

    remove_index :items, column: :name if index_exists?(:items, :name)
    add_index    :items, :name, unique: true

    # 3) tighten episodes
    change_column_null :episodes, :title,             false
    change_column_null :episodes, :number_in_season,  false
    # (keep location_id NOT NULL if you always have a location; otherwise set to true)

    # 4) PSR + days_lasted checks (Postgres CHECK constraints)
    add_check_constraint :appearances, "starting_psr >= 0 AND starting_psr <= 10", name: "appearances_starting_psr_0_10"
    add_check_constraint :appearances, "ending_psr   >= 0 AND ending_psr   <= 10", name: "appearances_ending_psr_0_10"
    add_check_constraint :appearances, "days_lasted IS NULL OR days_lasted >= 0",  name: "appearances_days_lasted_nonneg"

    # 5) country index for fast episode-by-country counts
    add_index :locations, :country unless index_exists?(:locations, :country)
  end
end
