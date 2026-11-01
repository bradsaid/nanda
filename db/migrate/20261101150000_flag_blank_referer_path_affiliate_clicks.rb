# Since commit 725c17d (deployed 2026-10-30 ~22:05 UTC) the buy buttons send the
# full same-site page URL as Referer (referrerpolicy="same-origin", no noreferrer),
# so a real browser click always stores a non-blank referring_path. Counted rows
# from that period with a NULL referring_path passed the "same-site Referer" check
# with a bare origin: automated traffic. Flag them (never delete).
#
# Rows before the cutoff are untouched: in the noreferrer era a NULL path was normal.
class FlagBlankRefererPathAffiliateClicks < ActiveRecord::Migration[8.0]
  CUTOFF = "2026-10-30 22:00:00".freeze # UTC, inclusive

  # created_at is stored in UTC. Idempotent: rerunning changes nothing new.
  BACKFILL_SQL = <<~SQL.squish.freeze
    UPDATE affiliate_clicks
    SET suspected_bot = TRUE
    WHERE suspected_bot = FALSE
      AND referring_path IS NULL
      AND created_at >= '#{CUTOFF}'
  SQL

  def up
    execute BACKFILL_SQL
  end

  # Deliberately a no-op rather than IrreversibleMigration: after this runs, the
  # flagged rows are indistinguishable from rows the app itself flagged with the
  # same rule (NULL path, suspected_bot) at click time, so an "undo" UPDATE would
  # wrongly un-flag those too. Nothing is deleted or lost; a flag can be cleared
  # by hand if ever needed.
  def down
  end
end
