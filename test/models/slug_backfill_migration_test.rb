require "test_helper"
require Rails.root.join("db/migrate/20261125180000_add_slug_to_episodes_and_items")

# The production backfill: rows that existed before the slug columns get slugs (and history
# rows) from the same generator new records use. Idempotent, collision-safe, and a row that
# cannot be slugged does not stop the others.
class SlugBackfillMigrationTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  def run_up
    migration = AddSlugToEpisodesAndItems.new
    migration.verbose = false
    migration.up
    Episode.reset_column_information
    Item.reset_column_information
  end

  def strip_slugs!
    Episode.update_all(slug: nil)
    Item.update_all(slug: nil)
    FriendlyId::Slug.where(sluggable_type: %w[Episode Item]).delete_all
  end

  setup do
    @series = Series.create!(name: "Naked and Afraid XL")
    @season = Season.create!(series: @series, number: 4, year: 2020)
    @e1 = Episode.create!(season: @season, number_in_season: 1, title: "Starting Out", location: locations(:one))
    @e2 = Episode.create!(season: @season, number_in_season: 2, title: "Starting Out", location: locations(:one))
    @i1 = Item.create!(name: "3 gallon bucket")
    @i2 = Item.create!(name: "3-gallon bucket")
    strip_slugs!
  end

  test "backfills every episode and item without a slug, and records them in friendly_id_slugs" do
    run_up
    assert_equal "naked-and-afraid-xl-s4e1-starting-out", @e1.reload.slug
    assert_equal "naked-and-afraid-xl-s4e2-starting-out", @e2.reload.slug
    assert_equal "3-gallon-bucket", @i1.reload.slug
    assert_equal "3-gallon-bucket-2", @i2.reload.slug
    assert_equal 0, Episode.where(slug: nil).count
    assert_equal 0, Item.where(slug: nil).count

    [Episode, Item].each do |model|
      history = FriendlyId::Slug.where(sluggable_type: model.name).pluck(:sluggable_id, :slug).to_h { |id, slug| [slug, id] }
      model.pluck(:id, :slug).each { |id, slug| assert_equal id, history[slug], "#{model.name} #{slug} missing from history" }
    end
  end

  test "it does not touch updated_at" do
    before = @e1.reload.updated_at
    run_up
    assert_equal before.to_f, @e1.reload.updated_at.to_f
  end

  test "it is idempotent: a second run changes nothing and adds no duplicate history" do
    run_up
    slugs   = Episode.order(:id).pluck(:slug) + Item.order(:id).pluck(:slug)
    history = FriendlyId::Slug.count
    run_up
    assert_equal slugs, Episode.order(:id).pluck(:slug) + Item.order(:id).pluck(:slug)
    assert_equal history, FriendlyId::Slug.count
  end

  test "rows that already have a slug keep it; only the missing ones are filled" do
    @e1.update_columns(slug: "keep-this-one")
    run_up
    assert_equal "keep-this-one", @e1.reload.slug
    assert_equal "naked-and-afraid-xl-s4e2-starting-out", @e2.reload.slug
    assert FriendlyId::Slug.exists?(sluggable_type: "Episode", sluggable_id: @e1.id, slug: "keep-this-one")
  end

  test "a row that fails is skipped and the rest are still done" do
    failing_id = @e1.id
    original = Episode.instance_method(:slug_source)
    Episode.send(:define_method, :slug_source) { id == failing_id ? raise("boom") : original.bind_call(self) }
    begin
      run_up
    ensure
      Episode.send(:define_method, :slug_source, original)
    end
    assert_nil @e1.reload.slug
    assert_equal "naked-and-afraid-xl-s4e2-starting-out", @e2.reload.slug
    assert_equal "3-gallon-bucket", @i1.reload.slug
  end

  test "after the backfill the half-migrated fallback is gone: every record links by slug" do
    run_up
    assert_equal "/episodes/naked-and-afraid-xl-s4e1-starting-out", Rails.application.routes.url_helpers.episode_path(@e1.reload)
    assert_equal "/items/3-gallon-bucket", Rails.application.routes.url_helpers.item_path(@i1.reload)
  end
end
