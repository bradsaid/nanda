namespace :survivors do
  desc "Fill survivor quick facts from a CSV (columns: slug,birth_year,hometown,nationality). " \
       "FILE=path/to/facts.csv. Dry run by default; WRITE=1 saves. Blank cells change nothing; safe to re-run."
  task import_facts: :environment do
    $stdout.sync = true
    path = ENV["FILE"].to_s
    abort "Usage: rake survivors:import_facts FILE=facts.csv [WRITE=1]  (columns: slug,birth_year,hometown,nationality)" if path.empty?
    abort "No such file: #{path}" unless File.file?(path)

    write = ENV["WRITE"] == "1"
    import = SurvivorFactsImport.from_file(path, write: write).run

    puts(write ? "== WRITE: importing survivor quick facts ==" : "== DRY RUN (nothing is saved; re-run with WRITE=1) ==")
    import.results.each do |r|
      detail =
        case r.status
        when :updated   then r.changes.map { |field, (from, to)| "#{field}: #{from.inspect} -> #{to.inspect}" }.join("; ")
        when :unchanged then "already up to date"
        else r.message
        end
      puts format("  line %-4d %-34s %-9s %s", r.line, r.slug, r.status, detail)
    end
    puts
    counts = import.counts
    puts "#{counts.fetch(:updated, 0)} #{write ? 'updated' : 'would be updated'}, #{counts.fetch(:unchanged, 0)} unchanged, " \
         "#{counts.fetch(:missing, 0)} slug not found, #{counts.fetch(:invalid, 0)} invalid, #{counts.fetch(:skipped, 0)} skipped"
    puts "Re-run with WRITE=1 to save." unless write
  end
end
