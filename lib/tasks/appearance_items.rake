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
    puts "Given items counted:"
    puts "  #{t[:units_before]}  raw rows (one per survivor, what a plain SUM sees today)"
    puts "  #{t[:units_once_per_episode]}  team items once per episode (the earlier rule)"
    puts "  #{t[:units_after]}  team items once per TEAM (the rule in force: 3+3+3+3 = 4 teams = 4 pots)"

    puts
    puts "Per item (raw rows / once per episode / once per team):"
    backfill.totals_by_item.sort_by { |_, v| -v[:per_team] }.first(15).each do |item_id, v|
      puts format("  %-24s %6d %6d %6d", Item.find_by(id: item_id)&.name.to_s.first(24), v[:rows], v[:once_per_episode], v[:per_team])
    end

    puts
    puts "By episode type (participant_arrangement):"
    puts format("  %-18s %6s %6s %11s %7s %6s %8s", "type", "teams", "team", "individual", "review", "rows", "counted")
    backfill.summary_by_type.each do |type, c|
      puts format("  %-18s %6d %6d %11d %7d %6d %8d", type, c[:teams], c[:team], c[:individual], c[:review], c[:rows], c[:counted])
    end

    review = backfill.review_groups
    puts
    puts "#{review.size} groups need a human look (individual ones count per row, as today):"
    if show_review
      review.sort_by { |g| [g.episode_id, g.item_id] }.each do |g|
        item = Item.find_by(id: g.item_id)&.name
        sub  = g.subtype.present? ? " (#{g.subtype})" : ""
        puts format("  - %-48s [%s] %s%s: %s", backfill.episode_label(g.episode_id).first(48), backfill.arrangement_for(g.episode_id), item, sub, g.reason)
      end
    else
      puts "  (hidden by REVIEW=0)"
    end

    unparseable = backfill.unparseable_arrangement_episodes
    puts
    puts "#{unparseable.size} episodes with 2+ survivors whose arrangement does not say how many teams (counted as 1 team; fix the arrangement if there were more):"
    unparseable.each do |ep|
      puts format("  - %-48s [%s]", backfill.episode_label(ep.id).first(48), ep.participant_arrangement.presence || "(none)")
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
