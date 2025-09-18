# frozen_string_literal: true
namespace :naf do
  desc "Import Naked & Afraid workbook (XLSX/CSV). FILE=path [DRY=1]"
  task import: :environment do
    path = ENV["FILE"] || abort("Usage: rake naf:import FILE=path/to.xlsx [DRY=1]")
    Naf::Importer.new(path, dry_run: ENV["DRY"].to_s == "1").run!
  end
end
