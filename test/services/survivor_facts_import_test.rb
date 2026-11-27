require "test_helper"

class SurvivorFactsImportTest < ActiveSupport::TestCase
  setup do
    @a = Survivor.create!(full_name: "Import Alpha")
    @b = Survivor.create!(full_name: "Import Beta", hometown: "Existing Town")
  end

  def csv(*lines) = (["slug,birth_year,hometown,nationality"] + lines).join("\n")

  test "a dry run reports what would change and saves nothing" do
    import = SurvivorFactsImport.new(csv("#{@a.slug},1985,Austin Texas,American"), write: false).run
    assert_equal({ updated: 1 }, import.counts)
    assert_nil @a.reload.birth_year
    assert_nil @a.hometown
    assert_equal [nil, 1985], import.results.first.changes["birth_year"]
  end

  test "WRITE saves the facts, and a second run changes nothing" do
    source = csv("#{@a.slug},1985,Austin Texas,American")
    SurvivorFactsImport.new(source, write: true).run
    @a.reload
    assert_equal [1985, "Austin Texas", "American"], [@a.birth_year, @a.hometown, @a.nationality]

    again = SurvivorFactsImport.new(source, write: true).run
    assert_equal({ unchanged: 1 }, again.counts)
  end

  test "blank cells never clear an existing value" do
    SurvivorFactsImport.new(csv("#{@b.slug},1990,,Canadian"), write: true).run
    @b.reload
    assert_equal "Existing Town", @b.hometown
    assert_equal 1990, @b.birth_year
    assert_equal "Canadian", @b.nationality
  end

  test "unknown slugs, bad years and blank rows are reported and do not stop the rest" do
    import = SurvivorFactsImport.new(csv("no-such-person,1985,X,Y", "#{@a.slug},nineteen,Z,", ",1990,,", "#{@b.slug},1991,,"), write: true).run
    statuses = import.results.map(&:status)
    assert_equal %i[missing invalid skipped updated], statuses
    assert_equal 1991, @b.reload.birth_year
    assert_nil @a.reload.birth_year
  end

  test "a future birth year is invalid and not saved" do
    import = SurvivorFactsImport.new(csv("#{@a.slug},#{Date.current.year + 1},,"), write: true).run
    assert_equal :invalid, import.results.first.status
    assert_nil @a.reload.birth_year
  end

  test "a CSV without a slug column is refused" do
    assert_raises(ArgumentError) { SurvivorFactsImport.new("name,birth_year\nx,1985").run }
  end

  test "a UTF-8 byte order mark on the header (spreadsheet export) is tolerated" do
    path = Rails.root.join("tmp/survivor_facts_import_test_#{SecureRandom.hex(4)}.csv")
    File.write(path, "\uFEFF#{csv("#{@a.slug},1985,,")}")
    import = SurvivorFactsImport.from_file(path, write: false).run
    assert_equal({ updated: 1 }, import.counts)
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
