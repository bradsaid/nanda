namespace :forum do
  desc "Seed the initial forum categories (idempotent)"
  task seed: :environment do
    categories = [
      { name: "General Discussion",     position: 10, description: "Everything Naked and Afraid. New here? Say hi." },
      { name: "Season Talk",             position: 20, description: "Live-episode reactions and season-by-season chat." },
      { name: "Meet the Survivalists",   position: 30, description: "Threads dedicated to individual survivors and their runs." },
      { name: "Speculation & Predictions", position: 40, description: "Who's going to tap? Where would you last longest?" },
      { name: "Item Talk",               position: 50, description: "Best (and worst) picks. Machete vs. bow, fire starters, and more." },
      { name: "Off Topic",               position: 60, description: "Not survival-related but you want to share it anyway." }
    ]

    categories.each do |attrs|
      c = Forum::Category.find_or_initialize_by(name: attrs[:name])
      c.assign_attributes(attrs)
      c.save!
      puts "#{c.new_record? ? 'created' : 'ok'}: #{c.name} (##{c.id}, /#{c.slug})"
    end

    puts "Total categories: #{Forum::Category.count}"
  end
end
