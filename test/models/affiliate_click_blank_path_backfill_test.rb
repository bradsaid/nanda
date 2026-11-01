require "test_helper"
require Rails.root.join("db/migrate/20261101150000_flag_blank_referer_path_affiliate_clicks")

# The origin-only-Referer backfill: counted rows created on/after 2026-10-30 22:00:00 UTC
# with a NULL referring_path become suspected_bot. Earlier rows (noreferrer era, where a NULL
# path was normal) and rows that have a path are untouched. Rows are never deleted.
class AffiliateClickBlankPathBackfillTest < ActiveSupport::TestCase
  Migration = FlagBlankRefererPathAffiliateClicks

  def make(at, path: nil, bot: false)
    AffiliateClick.create!(product_anchor: "p-x", referring_path: path, suspected_bot: bot, created_at: Time.utc(*at))
  end

  def run_backfill = ActiveRecord::Base.connection.execute(Migration::BACKFILL_SQL)

  test "flags counted NULL-path rows from the cutoff on, inclusive of 22:00:00 UTC, and nothing before" do
    flagged = [ make([ 2026, 10, 30, 22, 0, 0 ]), make([ 2026, 10, 30, 22, 5, 0 ]), make([ 2026, 10, 31, 12, 0, 0 ]),
                make([ 2026, 11, 1, 9, 0, 0 ]) ]
    untouched = [ make([ 2026, 10, 30, 21, 59, 59 ]), make([ 2026, 10, 30, 5, 0, 0 ]), make([ 2026, 10, 29, 23, 0, 0 ]) ]
    has_path = [ make([ 2026, 10, 30, 22, 0, 0 ], path: "/shop"), make([ 2026, 10, 31, 3, 0, 0 ], path: "/"),
                 make([ 2026, 11, 1, 8, 0, 0 ], path: "/survivors/12") ]
    before = AffiliateClick.count

    run_backfill

    assert_equal before, AffiliateClick.count, "no rows deleted"
    assert flagged.all? { |c| c.reload.suspected_bot }, "post-cutoff NULL-path rows flagged"
    assert untouched.none? { |c| c.reload.suspected_bot }, "pre-cutoff rows untouched"
    assert has_path.none? { |c| c.reload.suspected_bot }, "rows with a path untouched"
    assert_equal 4, AffiliateClick.suspected.count
    assert_equal 6, AffiliateClick.counted.count
  end

  test "rows already flagged stay flagged and keep their other columns" do
    c = make([ 2026, 10, 31, 1, 0, 0 ], bot: true)
    run_backfill
    assert c.reload.suspected_bot
    assert_nil c.referring_path
    assert_equal "p-x", c.product_anchor
  end

  test "is idempotent" do
    c = make([ 2026, 10, 31, 1, 0, 0 ])
    ok = make([ 2026, 10, 31, 2, 0, 0 ], path: "/shop")
    run_backfill
    run_backfill
    assert c.reload.suspected_bot
    assert_not ok.reload.suspected_bot
    assert_equal 1, AffiliateClick.suspected.count
  end

  test "the cutoff is 2026-10-30 22:00:00 UTC and the SQL has no deletes" do
    assert_equal "2026-10-30 22:00:00", Migration::CUTOFF
    assert_match(/\AUPDATE affiliate_clicks SET suspected_bot = TRUE WHERE suspected_bot = FALSE AND referring_path IS NULL AND created_at >= '2026-10-30 22:00:00'\z/,
                 Migration::BACKFILL_SQL)
    assert_no_match(/delete/i, Migration::BACKFILL_SQL)
  end

  test "down is a harmless no-op and up/down/up leaves the same result" do
    c = make([ 2026, 10, 31, 1, 0, 0 ])
    m = Migration.new
    m.verbose = false if m.respond_to?(:verbose=)
    ActiveRecord::Migration.suppress_messages do
      m.up
      m.down
      m.up
    end
    assert c.reload.suspected_bot
    assert_equal 1, AffiliateClick.count
  end

  test "the admin counted/suspected split stays a partition after the backfill" do
    make([ 2026, 10, 31, 1, 0, 0 ])
    make([ 2026, 10, 31, 2, 0, 0 ], path: "/shop")
    make([ 2026, 10, 29, 2, 0, 0 ])
    total = AffiliateClick.count
    run_backfill
    assert_equal total, AffiliateClick.counted.count + AffiliateClick.suspected.count
    assert_equal 2, AffiliateClick.counted.count
  end
end
