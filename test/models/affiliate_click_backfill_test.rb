require "test_helper"
require Rails.root.join("db/migrate/20261030170000_add_suspected_bot_to_affiliate_clicks")

# The release-time backfill: only clicks created 2026-10-30 05:00:00 <= t < 06:00:00 UTC
# (the scraper burst) are marked suspected_bot. Rows are never deleted.
class AffiliateClickBackfillTest < ActiveSupport::TestCase
  def make(at)
    AffiliateClick.create!(product_anchor: "p-x", created_at: Time.utc(*at))
  end

  def run_backfill = ActiveRecord::Base.connection.execute(AddSuspectedBotToAffiliateClicks::BACKFILL_SQL)

  test "flags exactly the burst window, inclusive of 05:00:00 and exclusive of 06:00:00 UTC" do
    inside = [ make([ 2026, 10, 30, 5, 0, 0 ]), make([ 2026, 10, 30, 5, 30, 12 ]), make([ 2026, 10, 30, 5, 59, 59 ]) ]
    outside = [ make([ 2026, 10, 30, 4, 59, 59 ]), make([ 2026, 10, 30, 6, 0, 0 ]), make([ 2026, 10, 29, 5, 30, 0 ]),
                make([ 2026, 10, 31, 5, 30, 0 ]) ]
    before = AffiliateClick.count

    run_backfill

    assert_equal before, AffiliateClick.count, "no rows deleted"
    assert inside.all? { |c| c.reload.suspected_bot }
    assert outside.none? { |c| c.reload.suspected_bot }
  end

  test "is idempotent" do
    c = make([ 2026, 10, 30, 5, 10, 0 ])
    run_backfill
    run_backfill
    assert c.reload.suspected_bot
    assert_equal 1, AffiliateClick.suspected.count
  end

  test "the window is the one-hour UTC burst (00:00-00:59 America/Chicago)" do
    assert_equal "2026-10-30 05:00:00", AddSuspectedBotToAffiliateClicks::BURST_START
    assert_equal "2026-10-30 06:00:00", AddSuspectedBotToAffiliateClicks::BURST_END
    chicago = ActiveSupport::TimeZone["America/Chicago"]
    assert_equal Time.utc(2026, 10, 30, 5), chicago.local(2026, 10, 30, 0).utc
  end

  test "counted and suspected scopes partition the table, and reports only use counted" do
    AffiliateClick.create!(product_anchor: "p-a", product_name: "A", placement: "shop")
    AffiliateClick.create!(product_anchor: "p-b", product_name: "B", placement: "bot", suspected_bot: true)
    assert_equal 1, AffiliateClick.counted.count
    assert_equal 1, AffiliateClick.suspected.count
    assert_equal({ [ "p-a", "A" ] => 1 }, AffiliateClick.top_products)
    assert_equal({ "shop" => 1 }, AffiliateClick.by_placement)
  end

  test "suspected_bot defaults to false and is not nullable" do
    col = AffiliateClick.columns_hash["suspected_bot"]
    assert_equal false, AffiliateClick.new.suspected_bot
    assert_not col.null
  end
end
