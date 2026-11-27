# Optional, admin-entered "quick facts" a survivor page may show: birth year, hometown and
# nationality (publicly shared basics only). All nullable and EMPTY by default; nothing is
# rendered for a survivor until a value is filled in (admin form or the
# survivors:import_facts rake task).
class AddQuickFactsToSurvivors < ActiveRecord::Migration[8.0]
  def up
    add_column :survivors, :birth_year,  :integer unless column_exists?(:survivors, :birth_year)
    add_column :survivors, :hometown,    :string  unless column_exists?(:survivors, :hometown)
    add_column :survivors, :nationality, :string  unless column_exists?(:survivors, :nationality)
    Survivor.reset_column_information
  end

  def down
    %i[nationality hometown birth_year].each do |col|
      remove_column :survivors, col if column_exists?(:survivors, col)
    end
  end
end
