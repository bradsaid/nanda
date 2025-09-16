namespace :naf do
  desc "Update survivors.avatar_url from XLSX (FullName + Instagram); uses IG cookie"
  task :import_instagram_avatars, [:path, :dry_run, :sheet] => :environment do |_t, args|
    path    = args[:path]  || ENV["PATH"]
    dry_run = ActiveModel::Type::Boolean.new.cast(args[:dry_run] || ENV["DRY_RUN"])
    sheet   = args[:sheet] || ENV["SHEET"]

    unless path && File.exist?(path)
      puts "ERROR: provide a valid path. Example:"
      puts %(  bin/rails 'naf:import_instagram_avatars[/Users/bradsaid/Desktop/avatars.xlsx,false,Survivalist Dashboard]')
      exit(1)
    end

    ImportInstagramAvatars.new(path: path, sheet_name: sheet, dry_run: dry_run).call
    puts "Done."
  end
end
