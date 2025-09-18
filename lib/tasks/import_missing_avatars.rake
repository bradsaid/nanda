# lib/tasks/import_missing_avatars.rake
namespace :naf do
  desc "Attach IG avatars only for survivors missing avatars"
  task :import_missing_avatars, [:path, :dry_run, :sheet] => :environment do |_t, args|
    logger = Logger.new($stdout)
    ImportMissingAvatars.new(
      path: args[:path] || ENV["PATH"],
      sheet_name: args[:sheet] || ENV["SHEET"],
      dry_run: ActiveModel::Type::Boolean.new.cast(args[:dry_run] || ENV["DRY_RUN"]),
      logger: logger
    ).call
  end
end
