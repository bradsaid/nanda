require "csv"

# Bulk-fills the optional survivor quick facts (birth year, hometown, nationality) from a
# CSV with the columns  slug,birth_year,hometown,nationality  (one survivor per row; the
# slug is the one in /survivors/<slug>). Used by `rake survivors:import_facts`.
#
#   * A blank cell never changes anything (it cannot clear a value; use the admin form).
#   * Re-running the same file changes nothing (rows already equal are reported unchanged).
#   * A slug that matches no survivor, or a row that fails validation (birth year not a
#     year, in the future), is reported and skipped; the other rows still import.
#   * Nothing is saved unless write: true (the rake task's WRITE=1).
class SurvivorFactsImport
  FIELDS = %w[birth_year hometown nationality].freeze

  Result = Struct.new(:line, :slug, :status, :changes, :message, keyword_init: true)

  attr_reader :results

  def initialize(source, write: false)
    @source  = source
    @write   = write
    @results = []
  end

  def self.from_file(path, write: false) = new(File.read(path, encoding: "bom|utf-8"), write: write)

  def run
    table = CSV.parse(@source.to_s, headers: true, skip_blanks: true)
    headers = table.headers.compact.map { |h| h.to_s.strip.downcase }
    raise ArgumentError, "CSV needs a slug column (columns: slug,birth_year,hometown,nationality)" unless headers.include?("slug")

    table.each.with_index(2) do |row, line| # line 1 is the header
      cells = row.to_h.transform_keys { |k| k.to_s.strip.downcase }
      process(line, cells)
    end
    self
  end

  def counts = results.group_by(&:status).transform_values(&:size)

  private

  def process(line, cells)
    slug = cells["slug"].to_s.strip
    return add(line, slug, :skipped, message: "no slug") if slug.empty?

    survivor = Survivor.find_by(slug: slug)
    return add(line, slug, :missing, message: "no survivor with this slug") unless survivor

    attrs = {}
    FIELDS.each do |field|
      value = cells[field].to_s.squish
      next if value.empty?
      attrs[field] = field == "birth_year" ? parse_year(value) : value
    end
    return add(line, slug, :invalid, message: "birth_year must be a whole year, like 1985") if attrs.key?("birth_year") && attrs["birth_year"].nil?

    survivor.assign_attributes(attrs)
    changes = survivor.changes.slice(*FIELDS).transform_values { |from, to| [from, to] }
    return add(line, slug, :unchanged, changes: {}) if changes.empty?
    return add(line, slug, :invalid, message: survivor.errors.full_messages.to_sentence) unless survivor.valid?

    survivor.save! if @write
    add(line, slug, :updated, changes: changes)
  end

  def parse_year(text)
    text.match?(/\A\d{4}\z/) ? text.to_i : nil
  end

  def add(line, slug, status, changes: {}, message: nil)
    @results << Result.new(line: line, slug: slug, status: status, changes: changes, message: message)
  end
end
