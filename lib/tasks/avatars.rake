require "csv"
require "open-uri"

namespace :avatars do
  desc "Attach avatars to survivors from a CSV (columns: survivor_id, image_url). Use DRY_RUN=1 to preview."
  task :ingest, [:csv_path] => :environment do |_t, args|
    csv_path = args[:csv_path] || ENV["CSV"] || "missing_avatars.csv"
    dry_run  = ENV["DRY_RUN"] == "1"

    abort "CSV not found at #{csv_path}" unless File.exist?(csv_path)

    rows = CSV.read(csv_path, headers: true)
    processed = 0
    attached  = 0
    skipped   = 0
    failed    = 0

    rows.each do |row|
      id        = row["survivor_id"].to_i
      image_url = row["image_url"].to_s.strip
      name      = row["full_name"].to_s

      next if image_url.empty?
      processed += 1

      survivor = Survivor.find_by(id: id)
      unless survivor
        puts "  [skip] no survivor with id=#{id} (#{name})"
        skipped += 1
        next
      end

      if survivor.avatar.attached?
        puts "  [skip] #{name} (id=#{id}) already has an avatar"
        skipped += 1
        next
      end

      if dry_run
        puts "  [dry]  would attach #{image_url} -> #{name} (id=#{id})"
        next
      end

      begin
        io = URI.parse(image_url).open(
          "User-Agent" => "Mozilla/5.0",
          read_timeout: 15,
          open_timeout: 10
        )
        content_type = io.respond_to?(:content_type) ? io.content_type : "image/jpeg"
        unless content_type.start_with?("image/")
          puts "  [fail] #{name}: not an image (#{content_type})"
          failed += 1
          next
        end

        ext = case content_type
              when "image/jpeg" then "jpg"
              when "image/png"  then "png"
              when "image/webp" then "webp"
              when "image/gif"  then "gif"
              else "jpg"
              end
        filename = "#{survivor.slug || survivor.id}.#{ext}"

        survivor.avatar.attach(io: io, filename: filename, content_type: content_type)
        puts "  [ok]   #{name} (id=#{id}) <- #{image_url}"
        attached += 1
      rescue => e
        puts "  [fail] #{name} (id=#{id}): #{e.class} #{e.message}"
        failed += 1
      end
    end

    puts ""
    puts "Done. processed=#{processed} attached=#{attached} skipped=#{skipped} failed=#{failed} dry_run=#{dry_run}"
  end
end
