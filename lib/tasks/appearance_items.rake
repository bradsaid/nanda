namespace :appearance_items do
  desc "Classify existing given items as team or individual (given_scope). " \
       "Dry run by default; WRITE=1 saves. Only touches rows whose given_scope is still NULL, so it is safe to re-run. " \
       "REVIEW=0 hides the per-item review list."
  task backfill_given_scope: :environment do
    $stdout.sync = true
    write = ENV["WRITE"] == "1"
    show_review = ENV["REVIEW"] != "0"

    backfill = GivenScopeBackfill.new.classify
    t = backfill.totals

    puts(write ? "== WRITE: classifying given items ==" : "== DRY RUN (nothing is saved; re-run with WRITE=1) ==")
    if backfill.groups.empty?
      puts "No unclassified given items. Nothing to do."
      next
    end

    puts
    puts "Unclassified given items: #{t[:rows]} rows = #{t[:groups]} (episode, item, subtype) groups across #{t[:episodes]} episodes"
    puts "  -> team:       #{t[:team_groups]} groups"
    puts "  -> individual: #{t[:individual_groups]} groups"
    puts "Given items counted by SUM(quantity): #{t[:units_before]} before, #{t[:units_after]} after (team items once per episode)"

    puts
    puts "By episode type (participant_arrangement):"
    puts format("  %-18s %6s %11s %7s %6s", "type", "team", "individual", "review", "rows")
    backfill.summary_by_type.each do |type, c|
      puts format("  %-18s %6d %11d %7d %6d", type, c[:team], c[:individual], c[:review], c[:rows])
    end

    review = backfill.review_groups
    puts
    puts "#{review.size} groups need a human look (left as 'individual', i.e. counted per row as today):"
    if show_review
      review.sort_by { |g| [g.episode_id, g.item_id] }.each do |g|
        item = Item.find_by(id: g.item_id)&.name
        sub  = g.subtype.present? ? " (#{g.subtype})" : ""
        puts format("  - %-48s [%s] %s%s: %s", backfill.episode_label(g.episode_id).first(48), backfill.arrangement_for(g.episode_id), item, sub, g.reason)
      end
    else
      puts "  (hidden by REVIEW=0)"
    end

    if write
      backfill.apply!
      puts
      puts "Saved #{t[:rows]} rows. Remaining unclassified given rows: #{AppearanceItem.given.where(given_scope: nil).count}"
    else
      puts
      puts "Dry run only. Re-run with WRITE=1 to save."
    end
  end
end
