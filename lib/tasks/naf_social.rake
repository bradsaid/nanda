# frozen_string_literal: true
namespace :naf do
  desc "Import Survivalist socials (IG/FB) from Survivalist Dashboard sheet"
  task :import_social, [:path, :dry_run, :sheet] => :environment do |_t, args|
    path    = args[:path]  || ENV["PATH"]
    dry_run = ActiveModel::Type::Boolean.new.cast(args[:dry_run] || ENV["DRY_RUN"])
    sheet   = args[:sheet] || ENV["SHEET"] || ImportSurvivalistSocialLinks::DEFAULT_SHEET

    unless path && File.exist?(path)
      puts "ERROR: provide a valid path. Example:"
      puts "  bin/rails 'naf:import_social[/Users/bradsaid/Desktop/NakedAndAfraidDB latest.xlsx,true]'"
      exit(1)
    end

    puts "Importing socials from: #{path} (sheet=#{sheet}, dry_run=#{dry_run})"
    ImportSurvivalistSocialLinks.new(path: path, sheet_name: sheet, dry_run: dry_run).call
    puts "Done."
  end
end
