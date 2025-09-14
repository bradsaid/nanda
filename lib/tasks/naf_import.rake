# frozen_string_literal: true
namespace :naf do
  desc "Import Naked & Afraid XLSX (usage: bin/rails 'naf:import[/path/to/file.xlsx]' or add ,true for dry-run)"
  task :import, [:path, :dry_run] => :environment do |_t, args|
    path    = args[:path] || ENV["PATH"]
    dry_run = ActiveModel::Type::Boolean.new.cast(args[:dry_run] || ENV["DRY_RUN"])

    unless path && File.exist?(path)
      puts "ERROR: provide a valid path. Example:"
      puts "  bin/rails 'naf:import[/absolute/path/NakedAndAfraidDB latest.xlsx]'"
      exit(1)
    end

    puts "Importing: #{path} (dry_run=#{dry_run})"
    ImportNakedAndAfraidWorkbook.new(path: path, dry_run: dry_run).call
    puts "Done."
  end
end
