# Usage:
#   bundle exec rake sep23:import
#   AVATARS=1 OVERWRITE=1 VERBOSE=1 ONLY='buckin' LIMIT=25 MIN_DELAY=1.5 MAX_DELAY=3.0 \
#   IG_COOKIES='...' FB_COOKIES='c_user=...; xs=...; datr=...' \
#   XLSX='/absolute/path.xlsx' \
#   bundle exec rake sep23:import

namespace :sep23 do
  desc "Run Sep23Import (imports workbook; optional IG/FB avatars)."
  task import: :environment do
    require Rails.root.join("app/services/sep23_import")

    path      = (ENV["XLSX"].presence || Sep23Import::DEFAULT_XLSX)
    avatars   = ENV["AVATARS"].to_s == "1"
    overwrite = ENV["OVERWRITE"].to_s == "1"
    verbose   = ENV["VERBOSE"].to_s == "1"
    only      = ENV["ONLY"]
    limit     = (ENV["LIMIT"].presence || 0).to_i
    min_d     = (ENV["MIN_DELAY"].presence || "2.0").to_f
    max_d     = (ENV["MAX_DELAY"].presence || "4.5").to_f
    ig_ck     = ENV["IG_COOKIES"]
    ig_ua     = ENV["IG_UA"]
    fb_ck     = ENV["FB_COOKIES"]

    unless File.exist?(path)
      puts "[FATAL] XLSX not found: #{path}"
      exit(1)
    end

    puts "[INFO] Importing from: #{path}"
    puts "[INFO] Avatars: #{avatars ? 'on' : 'off'} | Overwrite: #{overwrite ? 'yes' : 'no'} | Verbose: #{verbose ? 'yes' : 'no'}"

    Sep23Import.new(
      path,
      dry_run: false,
      avatars: avatars,
      overwrite_avatars: overwrite,
      verbose: verbose,
      only: only,
      limit: limit,
      min_delay: min_d,
      max_delay: max_d,
      ig_cookies: ig_ck,
      ig_user_agent: ig_ua,
      fb_cookies: fb_ck
    ).run!
  end

  desc "Dry run (no DB writes)."
  task dry_run: :environment do
    require Rails.root.join("app/services/sep23_import")
    path = (ENV["XLSX"].presence || Sep23Import::DEFAULT_XLSX)
    unless File.exist?(path)
      puts "[FATAL] XLSX not found: #{path}"
      exit(1)
    end
    Sep23Import.new(path, dry_run: true).run!
  end
end
