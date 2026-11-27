# Search aliases for survivors: spelling variants and nicknames people type into Google
# ("analis", "ally frueh", "jarrel banks") for someone we list under another spelling.
# A nullable text[] (nil = none); rendered as "Also searched as: ...", added to Person
# JSON-LD as alternateName and matched by the survivors search. Edited in the admin form
# as a comma-separated list (see Survivor#aliases_text).
class AddAliasesToSurvivors < ActiveRecord::Migration[8.0]
  def up
    add_column :survivors, :aliases, :text, array: true unless column_exists?(:survivors, :aliases)
    Survivor.reset_column_information
  end

  def down
    remove_column :survivors, :aliases if column_exists?(:survivors, :aliases)
  end
end
