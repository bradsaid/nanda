# app/services/import_naked_and_afraid_workbook.rb
# frozen_string_literal: true

require "roo"
require "csv"       # Ruby 3.4+: ensure csv is available for roo
require "bigdecimal"

class ImportNakedAndAfraidWorkbook
  SHEETS = %w[Regular Solo XL Frozen].freeze

  def initialize(path:, dry_run: false, logger: Rails.logger)
    @path     = path
    @dry_run  = dry_run
    @logger   = logger

    @series_cache   = {}
    @season_cache   = {}
    @location_cache = {}
    @survivor_cache = {}
    @item_cache     = {}
  end

  def call
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    xlsx = Roo::Spreadsheet.open(@path)
    @logger.info "Opened workbook: #{@path} (sheets=#{xlsx.sheets.join(", ")})"

    created_totals = Hash.new(0)

    ActiveRecord::Base.transaction do
      SHEETS.each do |sheet_name|
        next unless xlsx.sheets.include?(sheet_name)

        sheet_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @logger.info "=== Importing #{sheet_name} ==="

        counts = import_sheet(xlsx.sheet(sheet_name), sheet_name)

        counts.each { |k, v| created_totals[k] += v }
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - sheet_started).round(2)
        @logger.info "=== Finished #{sheet_name} in #{elapsed}s | " \
                     "episodes:+#{counts[:episodes]} survivors:+#{counts[:survivors]} items:+#{counts[:items]} " \
                     "appearances:+#{counts[:appearances]} appearance_items:+#{counts[:appearance_items]}"
      end

      if @dry_run
        @logger.info "DRY RUN enabled — rolling back."
        raise ActiveRecord::Rollback
      end
    end

    total_elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(2)
    @logger.info "=== Import summary (#{total_elapsed}s) ==="
    created_totals.each { |k, v| @logger.info "  #{k}: #{v}" }
  end

  private

  # Expected columns (best-effort; missing columns are handled):
  # Title | Season | Number | Series | AirDate | ScheduledDays | ParticipantArrangement | TypeModifiers
  # Location | PartnerReplacement | Starting PSR | Items | Given Items | Notes | Ending PSR | Participants_Expanded
  def import_sheet(sheet, sheet_name)
    header = sheet.row(1).map { |h| normalize_header(h) }
    counts = Hash.new(0)

    (2..sheet.last_row).each do |row_idx|
      begin
        raw_row = sheet.row(row_idx)
        row = header.zip(raw_row).to_h
        next if blank_row?(row)

        series_name  = pick(row, :series) || sheet_name
        season_num   = to_i_or_nil(pick(row, :season))
        ep_num       = to_i_or_nil(pick(row, :number))
        title_raw    = squeeze_text(pick(row, :title))
        title        = title_raw.presence || "Untitled #{series_name} S#{season_num}E#{ep_num}"

        air_date     = to_date_or_nil(pick(row, :air_date))
        sched_days   = to_i_or_nil(pick(row, :scheduled_days))
        arrangement  = squeeze_text(pick(row, :participant_arrangement))
        type_mods    = squeeze_text(pick(row, :type_modifiers))
        location_str = squeeze_text(pick(row, :location))
        notes        = squeeze_text(pick(row, :notes))

        start_psr    = to_decimal_or_nil(pick(row, :"starting_psr"))
        end_psr      = to_decimal_or_nil(pick(row, :"ending_psr"))
        partner_rep  = parse_partner_replacement(pick(row, :"partner_replacement"))
        participants = parse_participants(pick(row, :"participants_expanded"))
        brought_list = parse_items_list(pick(row, :items))
        given_list   = parse_items_list(pick(row, :"given_items"))
        pe_raw       = pick(row, :"participants_expanded")

        series   = upsert_series(series_name)
        season   = upsert_season(series, season_num)
        location = upsert_location(location_str)
        episode  = upsert_episode(season, ep_num, title, air_date, sched_days, arrangement, type_mods, location, notes)
        counts[:episodes] += 1 if episode.previously_new_record?

        # Build appearances first in the *same order* as participants
        appearances = participants.map do |full_name|
          survivor = upsert_survivor(full_name)
          counts[:survivors] += 1 if survivor.previously_new_record?

          ap = upsert_appearance(survivor, episode, start_psr, end_psr, sched_days, partner_rep, role_for(sheet_name), nil)
          counts[:appearances] += 1 if ap.previously_new_record?
          ap
        end

        # --- BROUGHT: zip items to survivors by order (preferred); then fallbacks ---
        created = assign_brought_items(appearances, brought_list, pe_raw, episode)
        counts[:items]            += created[:items]
        counts[:appearance_items] += created[:appearance_items]

        # --- GIVEN: attach to everyone (UI de-dupes once per episode) ---
        given_list.each do |item_name|
          item = upsert_item(item_name)
          counts[:items] += 1 if item&.previously_new_record?
          appearances.each do |ap|
            ai = upsert_appearance_item(ap, item, "given", 1)
            counts[:appearance_items] += 1 if ai&.previously_new_record?
          end
        end
      rescue => e
        @logger.error "Row #{row_idx} error in sheet #{sheet_name}: #{e.class} - #{e.message}"
        # @logger.error "Row data: #{raw_row.inspect}"
        next
      end
    end

    counts
  end

  # ---------- Upsert helpers (cached) ----------

  def upsert_series(name)
    key = name.to_s.downcase.strip
    @series_cache[key] ||= Series.find_or_create_by!(name:)
  end

  def upsert_season(series, number)
    number ||= 0
    key = "#{series.id}-#{number}"
    @season_cache[key] ||= Season.find_or_create_by!(series:, number:)
  end

  def upsert_location(raw)
    country, region, site = parse_location(raw)
    key = [country, region, site].map { |s| s.to_s.downcase }.join("|")
    @location_cache[key] ||= Location.find_or_create_by!(country:, region:, site:)
  end

  def upsert_episode(season, number_in_season, title, air_date, scheduled_days, arrangement, type_mods, location, notes)
    Episode.find_or_create_by!(season:, number_in_season:) do |e|
      e.title = title
      e.air_date = air_date
      e.scheduled_days = scheduled_days
      e.participant_arrangement = arrangement
      e.type_modifiers = type_mods
      e.location = location
      e.notes = notes
    end
  end

  def upsert_survivor(full_name)
    key = full_name.to_s.downcase.strip
    @survivor_cache[key] ||= Survivor.find_or_create_by!(full_name:)
  end

  def upsert_item(name)
    return nil if name.blank?
    key = name.to_s.downcase.strip
    @item_cache[key] ||= Item.find_or_create_by!(name: canonical_item_name(name))
  end

  def upsert_appearance(survivor, episode, starting_psr, ending_psr, days_lasted, partner_replacement, role, notes)
    Appearance.find_or_create_by!(survivor:, episode:) do |a|
      a.starting_psr = starting_psr
      a.ending_psr = ending_psr
      a.days_lasted = days_lasted
      a.partner_replacement = partner_replacement
      a.role = role
      a.notes = notes
    end
  end

  def upsert_appearance_item(appearance, item, source, quantity)
    return nil if item.nil?
    AppearanceItem.find_or_create_by!(appearance:, item:, source:) do |ai|
      ai.quantity = quantity
    end
  end

  # ---------- BROUGHT assignment ----------

  # Returns { items: X, appearance_items: Y }
  def assign_brought_items(appearances, brought_list, participants_expanded_raw, episode)
    created = { items: 0, appearance_items: 0 }
    return created if appearances.blank? || brought_list.blank?

    # 1) Preferred: counts match → zip by order (e.g., "Kim, Shane" ↔ "Machete, Fire Starter")
    if appearances.size == brought_list.size
      appearances.zip(brought_list).each do |ap, item_name|
        next if item_name.blank?
        item = upsert_item(item_name)
        created[:items] += 1 if item&.previously_new_record?
        ai = upsert_appearance_item(ap, item, "brought", 1)
        created[:appearance_items] += 1 if ai&.previously_new_record?
      end
      return created
    end

    # 2) Fallback: explicit pairs in Participants_Expanded (e.g., "Name (Machete)" or "Name - Machete")
    mapping = parse_name_item_pairs(participants_expanded_raw) # { "Full Name" => "Item" }
    if mapping.present?
      appearances.each do |ap|
        next unless (item_name = mapping[ap.survivor.full_name]).present?
        item = upsert_item(item_name)
        created[:items] += 1 if item&.previously_new_record?
        ai = upsert_appearance_item(ap, item, "brought", 1)
        created[:appearance_items] += 1 if ai&.previously_new_record?
      end
      return created
    end

    # 3) Last resort: truncate to min size, log the mismatch
    min = [appearances.size, brought_list.size].min
    if min > 0
      appearances.first(min).zip(brought_list.first(min)).each do |ap, item_name|
        next if item_name.blank?
        item = upsert_item(item_name)
        created[:items] += 1 if item&.previously_new_record?
        ai = upsert_appearance_item(ap, item, "brought", 1)
        created[:appearance_items] += 1 if ai&.previously_new_record?
      end
      @logger.warn "Brought truncated: items=#{brought_list.size} participants=#{appearances.size} for #{episode_debug(episode)}"
    else
      @logger.warn "Brought mismatch and no mapping for #{episode_debug(episode)} — skipped brought assignment."
    end

    created
  end

  # Parses pairs like:
  # "Shane Lewis (Machete) & Kim Shelton (Fire Starter)"
  # "Shane Lewis - Machete, Kim Shelton - Fire Starter"
  def parse_name_item_pairs(raw)
    s = raw.to_s
    return {} if s.strip.empty?

    pairs = {}
    s.split(/[,&]/).each do |chunk|
      chunk = chunk.strip
      if chunk =~ /\A(.+?)\s*[\(\-–]\s*([^)]+?)\s*\)?\z/
        name = $1.strip
        item = canonical_item_name($2.strip)
        pairs[name] = item
      end
    end
    pairs
  end

  # ---------- Parsers ----------

  def normalize_header(h)
    h.to_s.strip.downcase
      .gsub(/\s+/, "_")
      .gsub(/[()]/, "")
      .gsub(/-/, "_")
  end

  def pick(row, key)
    # tolerate different header spellings
    aliases = {
      starting_psr: ["starting_psr", "starting_psr_"],
      ending_psr:   ["ending_psr", "ending_psr_"],
      given_items:  ["given_items", "given_item", "given"]
    }
    keys = [key.to_s] + Array(aliases[key]).to_a
    found = keys.find { |k| row.key?(k) }
    row[found]
  end

  def blank_row?(row)
    row.values.compact.map(&:to_s).all?(&:blank?)
  end

  def squeeze_text(v)
    v.to_s.strip.gsub(/\s+/, " ")
  end

  def to_i_or_nil(v)
    Integer(v) rescue nil
  end

  def to_decimal_or_nil(v)
    return nil if v.nil?
    str = v.to_s.strip
    return nil if str.blank?
    BigDecimal(str) rescue nil
  end

  def to_date_or_nil(v)
    return v.to_date if v.respond_to?(:to_date)
    Date.parse(v.to_s) rescue nil
  end

  def parse_partner_replacement(v)
    s = v.to_s.strip.downcase
    return true  if %w[yes y true t 1 replaced].include?(s)
    return false if %w[no n false f 0].include?(s)
    nil
  end

  def parse_participants(raw)
    s = raw.to_s
    return [] if s.strip.empty?
    s.split(/[,&]| and /i)
     .map(&:strip)
     .map { |name| name.sub(/\s*\([^)]*\)\s*\z/, "") } # drop trailing "(Item)" from names
     .reject(&:blank?)
  end

  def parse_items_list(raw)
    s = raw.to_s
    return [] if s.strip.empty?
    s.split(/[,&]| and /i)
     .map { |name| canonical_item_name(name) }
     .reject(&:blank?)
     .uniq
  end

  def canonical_item_name(name)
    s = name.to_s.strip
    s = s.sub(/\Aan?\s+/i, "") # drop leading a/an
    s = s.gsub(/\b(firestarter|fire starter)\b/i, "Fire Starter")
    s = s.titleize
    s
  end

  # "Peru, Madre de Dios - Lago Sandoval" -> ["Peru", "Madre de Dios", "Lago Sandoval"]
  def parse_location(raw)
    s = raw.to_s.strip
    return ["Unknown", nil, nil] if s.blank?

    country, rest = s.split(",", 2).map { |x| x&.strip }
    region, site  = rest&.split("-", 2)&.map(&:strip)
    [country || "Unknown", region, site]
  end

  def role_for(sheet_name)
    case sheet_name
    when "Solo"   then "solo"
    when "XL"     then "xl_team"
    when "Frozen" then "frozen"
    else               "duo"
    end
  end

  def episode_debug(ep)
    return "unknown" unless ep
    ser = ep.season&.series&.name
    "S#{ep.season&.number}E#{ep.number_in_season} #{ser}"
  end
end
