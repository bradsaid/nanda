# Flags clicks that look automated so the admin report can leave them out
# (they're kept, not deleted), and flags the one-hour scraper burst already stored:
# 2026-10-30 05:00-05:59 UTC (00:00-00:59 America/Chicago), 369 rows in production.
class AddSuspectedBotToAffiliateClicks < ActiveRecord::Migration[8.0]
  BURST_START = "2026-10-30 05:00:00".freeze # UTC, inclusive
  BURST_END   = "2026-10-30 06:00:00".freeze # UTC, exclusive

  # created_at is stored in UTC. Idempotent: rerunning changes nothing new.
  BACKFILL_SQL = <<~SQL.squish.freeze
    UPDATE affiliate_clicks
    SET suspected_bot = TRUE
    WHERE created_at >= '#{BURST_START}' AND created_at < '#{BURST_END}'
      AND suspected_bot = FALSE
  SQL

  def up
    add_column :affiliate_clicks, :suspected_bot, :boolean, null: false, default: false
    add_index  :affiliate_clicks, %i[suspected_bot created_at]
    execute BACKFILL_SQL
  end

  def down
    remove_index  :affiliate_clicks, %i[suspected_bot created_at]
    remove_column :affiliate_clicks, :suspected_bot
  end
end
