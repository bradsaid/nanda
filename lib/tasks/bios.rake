require "json"

namespace :bios do
  desc "Apply bios from a JSONL file (one survivor per line). Usage: rake bios:apply[path]"
  task :apply, [:path] => :environment do |_, args|
    path = args[:path] or abort("usage: rake bios:apply[path/to/file.jsonl]")
    abort("File not found: #{path}") unless File.exist?(path)

    now = Time.current
    counts = Hash.new(0)
    unresolved_eps = []
    unresolved_srs = []

    ep_link = ->(title) {
      e = Episode.where("LOWER(title) = LOWER(?)", title).first
      e ||= Episode.where("title ILIKE ?", title).first
      next nil unless e
      s = e.season
      series = s&.series
      label = if series && s
        %(#{series.name} S#{s.number}E#{e.number_in_season} "#{e.title}")
      else
        e.title
      end
      %(<a href="/episodes/#{e.id}">#{label}</a>)
    }

    series_link = ->(name) {
      # Try exact, then a few common variants
      candidates = [name, name.sub(/: /, " "), name.sub(/ /, ": "), name.gsub(":", "")]
      candidates.each do |c|
        if Series.find_by(name: c)
          return %(<a href="/seasons">#{name}</a>)
        end
      end
      # Loose ILIKE fallback
      if Series.where("name ILIKE ?", "%#{name.gsub(":", "").strip}%").exists?
        return %(<a href="/seasons">#{name}</a>)
      end
      nil
    }

    survivor_link = ->(name) {
      s = Survivor.find_by(full_name: name)
      s ||= Survivor.where("full_name ILIKE ?", name).first
      next nil unless s
      slug = s.slug.presence || s.id.to_s
      %(<a href="/survivors/#{slug}">#{name}</a>)
    }

    resolve = ->(bio) {
      next bio if bio.nil?
      bio.gsub(/\{\{ep:([^}]+)\}\}/) do
        t = $1.strip
        if (l = ep_link.call(t)); l; else unresolved_eps << t; %(<em>"#{t}"</em>); end
      end.gsub(/\{\{series:([^}]+)\}\}/) do
        n = $1.strip
        if (l = series_link.call(n)); l; else unresolved_srs << n; %(<em>#{n}</em>); end
      end.gsub(/\{\{survivor:([^}]+)\}\}/) do
        n = $1.strip
        if (l = survivor_link.call(n)); l; else n; end
      end
    }

    File.foreach(path) do |line|
      line.strip!
      next if line.empty?
      data = JSON.parse(line)
      s = Survivor.find_by(full_name: data["name"])
      unless s
        puts "MISSING: #{data["name"]}"
        counts[:missing] += 1
        next
      end
      status = data["status"] || "not_found"
      updates = {
        bio_source_url: data["source"],
        bio_checked_at: now,
        bio_lookup_status: status
      }
      resolved = resolve.call(data["bio"])
      updates[:bio] = resolved if resolved.present?
      (data["add_links"] || {}).each do |field, url|
        next if url.to_s.strip.empty?
        next unless %w[instagram facebook youtube website cameo other merch].include?(field.to_s)
        next if s.send(field).present?
        updates[field.to_sym] = url
      end
      s.update!(updates)
      counts[status.to_sym] += 1
    end

    puts "Counts: #{counts.to_h.inspect}"
    puts "Unresolved episodes: #{unresolved_eps.uniq.inspect}" if unresolved_eps.any?
    puts "Unresolved series: #{unresolved_srs.uniq.inspect}"   if unresolved_srs.any?
  end
end
