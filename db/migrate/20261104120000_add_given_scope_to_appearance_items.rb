# Records whether a "given" item was one item handed to the whole team ("team")
# or one item handed to each person ("individual").
#
# The show usually gives ONE item to the team, but the app stores a row per
# survivor so every survivor's page can show what they had access to. Without a
# marker, anything that tallies given items counts one team item once per
# survivor. See AppearanceItem.counted for the counting rule.
#
# NULL means "not a given item" for brought/found rows, and "not classified yet"
# for given rows that predate this column (rake appearance_items:backfill_given_scope
# fills those in). Unclassified given rows count per row, exactly as they did
# before this migration, so deploying changes no number until the backfill runs.
#
# There is deliberately no column default: the right default (team) only applies
# when source = 'given', which a column default cannot express. The model and the
# admin form supply "team" for new given rows.
class AddGivenScopeToAppearanceItems < ActiveRecord::Migration[8.0]
  def change
    add_column :appearance_items, :given_scope, :string

    add_check_constraint :appearance_items,
      "given_scope IS NULL OR given_scope IN ('team', 'individual')",
      name: "appearance_items_given_scope_values"

    add_check_constraint :appearance_items,
      "given_scope IS NULL OR source = 'given'",
      name: "appearance_items_given_scope_only_given"
  end
end
