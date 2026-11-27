# Applies the curated search aliases (SurvivorAliasSeed::ALIASES, derived from Search Console
# queries: spelling variants and nicknames of survivors that exist) to the survivors table.
# Data only, tolerant of missing survivors (skipped and reported) and idempotent (aliases
# are merged into whatever a survivor already has; running it twice changes nothing).
# updated_at is left alone: an alias is not a content edit worth a new "last updated" date.
class SeedSurvivorAliases < ActiveRecord::Migration[8.0]
  def up
    Survivor.reset_column_information
    return unless Survivor.column_names.include?("aliases")
    result = SurvivorAliasSeed.apply!
    say "Survivor aliases: #{result[:updated]} survivors updated, #{result[:unchanged]} already complete, " \
        "#{result[:missing].size} not found#{" (#{result[:missing].join(', ')})" if result[:missing].any?}", true
  end

  def down
    # Seeded aliases are plain data; there is nothing to undo that would not also drop admin edits.
  end
end
