# Hyphenated URLs for episodes and items (/episodes/naked-and-afraid-s14e2-haunted-and-hungry,
# /items/fire-starter). The columns are nullable on purpose: until a row has a slug its
# #to_param is its id and /episodes/<id> still works, so a half-migrated database cannot 500.
#
# The backfill uses the models' own slug generator (Episode#slug_source / Item#normalize_friendly_id
# and the "-2" collision rule), so a slug generated here and one generated for a new record
# follow the same rules. It is idempotent (only rows without a slug are touched, history rows
# are only added when missing), batched, and tolerant: a row that fails is reported and skipped
# (each in its own savepoint) rather than failing the deploy; it is picked up on the next save,
# or by re-running the migration's backfill.
class AddSlugToEpisodesAndItems < ActiveRecord::Migration[8.0]
  BATCH = 200

  def up
    add_column :episodes, :slug, :string unless column_exists?(:episodes, :slug)
    add_column :items,    :slug, :string unless column_exists?(:items, :slug)
    add_index :episodes, :slug, unique: true unless index_exists?(:episodes, :slug)
    add_index :items,    :slug, unique: true unless index_exists?(:items, :slug)

    Episode.reset_column_information
    Item.reset_column_information

    backfill(Episode, Episode.includes(season: :series))
    backfill(Item, Item.all)
    record_history("episodes", "Episode")
    record_history("items", "Item")
  end

  def down
    remove_index :episodes, :slug if index_exists?(:episodes, :slug)
    remove_index :items,    :slug if index_exists?(:items, :slug)
    remove_column :episodes, :slug if column_exists?(:episodes, :slug)
    remove_column :items,    :slug if column_exists?(:items, :slug)
    # The history rows are left in friendly_id_slugs only if the columns are re-added;
    # remove them so a later run starts clean.
    execute "DELETE FROM friendly_id_slugs WHERE sluggable_type IN ('Episode', 'Item')"
  end

  private

  def backfill(model, scope)
    done = failed = 0
    scope.where(slug: nil).find_each(batch_size: BATCH) do |record|
      ActiveRecord::Base.transaction(requires_new: true) do
        record.send(:set_slug)
        raise "no slug generated" if record.slug.blank?
        record.update_columns(slug: record.slug)
        # Written straight away: the generator's conflict check for the next row reads
        # the history table, so every slug already handed out must be in it.
        insert_history(model, record)
      end
      done += 1
    rescue StandardError => e
      failed += 1
      say "#{model.name} ##{record.id}: slug not generated (#{e.class}: #{e.message})"
    end
    say "#{model.name}: #{done} slugs generated#{", #{failed} failed" if failed.positive?}", true
  end

  def insert_history(model, record)
    execute <<~SQL.squish
      INSERT INTO friendly_id_slugs (slug, sluggable_id, sluggable_type, created_at)
      SELECT #{quote(record.slug)}, #{record.id.to_i}, #{quote(model.base_class.name)}, NOW()
       WHERE NOT EXISTS (
         SELECT 1 FROM friendly_id_slugs
          WHERE slug = #{quote(record.slug)} AND sluggable_type = #{quote(model.base_class.name)})
    SQL
  end

  # History only records a slug when a record is next saved, so without this the current slug
  # of a row that already had one (a re-run) would be lost the first time it changed.
  def record_history(table, type)
    execute <<~SQL.squish
      INSERT INTO friendly_id_slugs (slug, sluggable_id, sluggable_type, created_at)
      SELECT t.slug, t.id, #{quote(type)}, NOW()
        FROM #{table} t
       WHERE t.slug IS NOT NULL AND t.slug <> ''
         AND NOT EXISTS (SELECT 1 FROM friendly_id_slugs s
                          WHERE s.slug = t.slug AND s.sluggable_type = #{quote(type)})
    SQL
  end
end
