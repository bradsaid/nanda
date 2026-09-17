# Topic URLs carry no category segment, but slugs were unique only per
# category, so two topics could share one URL and the loser became
# unreachable. Deduplicate what exists, then let the database enforce it.
class EnforceForumTopicSlugUniqueness < ActiveRecord::Migration[8.0]
  def up
    duplicated = select_values(
      "SELECT slug FROM forum_topics GROUP BY slug HAVING COUNT(*) > 1"
    )

    duplicated.each do |slug|
      # Oldest keeps the bare slug — it is the one most likely to have inbound
      # links. Everything newer gets a suffix.
      ids = select_values(
        "SELECT id FROM forum_topics WHERE slug = #{quote(slug)} ORDER BY id ASC"
      )
      ids.drop(1).each do |id|
        new_slug = "#{slug}-#{SecureRandom.hex(4)}"
        execute "UPDATE forum_topics SET slug = #{quote(new_slug)} WHERE id = #{id}"
        say "topic #{id}: #{slug} -> #{new_slug}"
      end
    end

    add_index :forum_topics, :slug, unique: true, name: "index_forum_topics_on_slug_unique"
  end

  def down
    remove_index :forum_topics, name: "index_forum_topics_on_slug_unique"
  end
end
