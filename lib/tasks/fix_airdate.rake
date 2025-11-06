# lib/tasks/fix_airdate.rake
namespace :episodes do
  desc "Update an episode's air_date (usage: EP='Firing Squad' DATE='2024-09-15' COMMIT=1)"
  task fix_airdate: :environment do
    title  = ENV["EP"]
    date   = ENV["DATE"]
    commit = ENV["COMMIT"] == "1"

    abort "Provide EP='title' and DATE='YYYY-MM-DD'" unless title.present? && date.present?

    eps = Episode.where("LOWER(title) LIKE ?", "%#{title.downcase}%")
    if eps.empty?
      puts "No episode found matching '#{title}'"
      next
    end

    puts "Found #{eps.size} episode(s):"
    eps.each { |e| puts "  ##{e.id}  #{e.title} (current: #{e.air_date || 'nil'})" }

    if commit
      eps.each { |e| e.update!(air_date: Date.parse(date)) }
      puts "\n✅ Updated #{eps.size} episode(s) to #{date}"
    else
      puts "\nDry run only. Use COMMIT=1 to write."
    end
  end
end
