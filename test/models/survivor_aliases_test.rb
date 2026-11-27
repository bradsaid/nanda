require "test_helper"
require Rails.root.join("db/migrate/20261127120200_seed_survivor_aliases")

# Search aliases on survivors: tidy-up rules, the search scope, and the curated seed
# (idempotent, tolerant of survivors that do not exist).
class SurvivorAliasesTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  test "clean_aliases strips, squishes, dedupes case-insensitively, drops the name itself and caps the list" do
    cleaned = Survivor.clean_aliases([" Ally ", "ally", "Allison  Frueh", "", nil, "Ally Frueh"], full_name: "Allison Frueh")
    assert_equal ["Ally", "Ally Frueh"], cleaned

    assert_equal ["A", "B", "C"], Survivor.clean_aliases("A, B;C\nb")
    assert_equal Survivor::MAX_ALIASES, Survivor.clean_aliases((1..50).map { |i| "alias #{i}" }).size
    assert_equal Survivor::MAX_ALIAS_LENGTH, Survivor.clean_aliases(["x" * 200]).first.length
  end

  test "aliases are normalized on save and an empty list is stored as nil" do
    s = Survivor.create!(full_name: "Alias Tester One", aliases: ["  Ali T ", "ali t", "Alias Tester One"])
    assert_equal ["Ali T"], s.reload.aliases

    s.update!(aliases_text: "")
    assert_nil s.reload.aliases
  end

  test "aliases_text round-trips as a comma-separated string" do
    s = Survivor.new(full_name: "Alias Tester Two")
    s.aliases_text = "Annalise, Analis,Annalise"
    assert_equal ["Annalise", "Analis"], s.aliases
    assert_equal "Annalise, Analis", s.aliases_text
  end

  test "matching_name_or_alias finds by name or by alias, case-insensitively, and treats % and _ literally" do
    s = Survivor.create!(full_name: "Alias Tester Three", aliases: ["Zanzibar Nick"])
    other = Survivor.create!(full_name: "Someone Else Entirely")
    assert_includes Survivor.matching_name_or_alias("%zanzibar%"), s
    assert_includes Survivor.matching_name_or_alias("%tester three%"), s
    assert_not_includes Survivor.matching_name_or_alias("%zanzibar%"), other
    assert_empty Survivor.matching_name_or_alias("%nope-no-match%")
    assert_empty Survivor.matching_name_or_alias("%#{ActiveRecord::Base.sanitize_sql_like('z_nzibar')}%")
  end

  # ---- the curated seed ----

  test "every seeded alias list is clean and never repeats a survivor's own name" do
    SurvivorAliasSeed::ALIASES.each do |entry|
      assert_equal entry[:aliases], Survivor.clean_aliases(entry[:aliases], full_name: entry[:name]), "#{entry[:slug]} has duplicate or self aliases"
      assert_operator entry[:aliases].size, :<=, Survivor::MAX_ALIASES
    end
    slugs = SurvivorAliasSeed::ALIASES.map { |e| e[:slug] }
    assert_equal slugs.uniq, slugs
  end

  test "the seed never lists a bare ambiguous first name" do
    ambiguous = %w[ali allie alison joe johnny sam lily lilly marina teal pablo ana anna adam gary jamie tyler holly laura julia malu rene]
    all = SurvivorAliasSeed::ALIASES.flat_map { |e| e[:aliases] }.map(&:downcase)
    assert_empty all & ambiguous
  end

  test "apply! adds aliases to survivors that exist, skips the ones that do not, and is idempotent" do
    ana = Survivor.create!(full_name: "Ana Lis Pitter")
    result = SurvivorAliasSeed.apply!
    assert_equal 1, result[:updated]
    assert_equal SurvivorAliasSeed::ALIASES.size - 1, result[:missing].size
    assert_not_includes result[:missing], "ana-lis-pitter"
    assert_includes ana.reload.aliases, "Annalise"
    assert_includes ana.aliases, "Analis"

    again = SurvivorAliasSeed.apply!
    assert_equal 0, again[:updated]
    assert_equal 1, again[:unchanged]
    assert_equal ana.aliases, Survivor.find(ana.id).aliases
  end

  test "apply! keeps aliases an admin added and does not touch updated_at" do
    ally = Survivor.create!(full_name: "Allison Frueh", aliases: ["My Own Nickname"])
    stamp = ally.reload.updated_at
    travel 1.day do
      SurvivorAliasSeed.apply!
    end
    ally.reload
    assert_equal "My Own Nickname", ally.aliases.first
    assert_includes ally.aliases, "Ally"
    assert_equal stamp.to_f, ally.updated_at.to_f
  end

  test "apply! finds a survivor by name when the slug has changed" do
    s = Survivor.create!(full_name: "Gary Golding")
    s.update_columns(slug: "gary-g")
    SurvivorAliasSeed.apply!
    assert_equal ["Gary Goulding"], s.reload.aliases
  end

  test "the migration runs the seed, is idempotent and tolerates every survivor missing" do
    migration = SeedSurvivorAliases.new
    migration.verbose = false
    assert_nothing_raised { migration.up } # none of the seeded survivors exist in the fixtures

    Survivor.create!(full_name: "Jarrell Banks")
    migration.up
    first = Survivor.find_by(full_name: "Jarrell Banks").aliases
    assert_includes first, "Jarrel Banks"
    migration.up
    assert_equal first, Survivor.find_by(full_name: "Jarrell Banks").aliases
  end
end
