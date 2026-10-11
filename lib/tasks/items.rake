namespace :items do
  desc "Re-run Item.classify over every item and fix wrong item_types. " \
       "Dry run unless APPLY=1 (e.g. `APPLY=1 bin/rails items:reclassify`)"
  task reclassify: :environment do
    $stdout.sync = true
    apply   = ENV["APPLY"] == "1"
    changes = Item.order(:name).filter_map do |item|
      wanted = Item.classify(item.name)
      [item, item.item_type, wanted] if wanted != item.item_type
    end

    changes.each do |item, from, to|
      puts format("%-36s %-20s -> %s", item.name, from.inspect, to)
    end

    if apply
      # update_columns skips validations (and the classifier callback), but we
      # bump updated_at on purpose: /items caches on Item.maximum(:updated_at),
      # so this is what makes the corrected types show up.
      changes.each { |item, _from, to| item.update_columns(item_type: to, updated_at: Time.current) }
      puts "Updated #{changes.size} of #{Item.count} items."
    else
      puts "#{changes.size} of #{Item.count} items would change. Re-run with APPLY=1 to write them."
    end
  end
end
