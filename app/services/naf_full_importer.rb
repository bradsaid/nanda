# app/services/naf_full_importer.rb
# frozen_string_literal: true

require "roo"
require "csv"       # Ruby 3.4+: roo needs csv explicitly
require "date"
require "bigdecimal"

class NafFullImporter
  SHEETS         = %w[Regular Solo XL Frozen].freeze
  SOCIALS_SHEET  = "Survivalist Dashboard"

  def initialize(path:, dry_run: false, wipe: false, logger: Rails.logger)
    @path    = path
    @dry_run = dry_run
    @wipe    = wipe
    @logger  = logger

    # caches
    @series_cache   = {}
    @season_cache   = {}
    @location_cache = {}
    @survivor_cache = {}
    @item_cache     = {}
  end

  def call
    start_time = monotime
    xlsx = Roo::Spreadsheet.open(@path)
    @logger.info "Opened workbook: #{@path} (sheets=#{xlsx.sheets.join(", ")})"

    ActiveRecord::Base.transaction do
      wipe_data! if @wipe

      totals = Hash.new(0)

      SHEETS.each do |sheet_name|
        next unless xlsx.sheets.include?(sheet_name)
        @logger.info "=== Importing #{sheet_name} ==="
        t0 = monotime
        counts = import_episodes_sheet(xlsx.sheet(sheet_name), sheet_name)
        counts.each { |k, v| totals[k] += v }
        @logger.info "=== Finished #{sheet_name} in #{(monotime - t0).round(2)}s | " \
                     "episodes:+#{counts[:episodes]} survivors:+#{counts[:survivors]} items:+#{counts[:items]} " \
                     "appearances:+#{counts[:appearances]} appearance_items:+#{counts[:appearance_items]}"
      end

      if xlsx.sheets.include?(SOCIALS_SHEET)
        @logger.info "=== Importing socials from '#{SOCIALS_SHEET}' ==="
        t0 = monotime
        social_stats = import_socials_sheet(xlsx.sheet(SOCIALS_SHEET))
        @logger.info "=== Finished socials in #{(monotime - t0).round(2)}s | updated:#{social_stats[:updated]} unchanged:#{social_stats[:unchanged]} "\
                     "not_found:#{social_stats[:not_found]} missing_name:#{social_stats[:missing_name]} errors:#{social_stats[:errors]}"
      else
        @logger.warn "Socials sheet '#{SOCIALS_SHEET}' not found; skipping."
      end

      if @dry_run
        @logger.info "DRY RUN enabled — rolling back."
        raise ActiveRecord::Rollback
      end

      @logger.info "=== Import summary (#{(monotime - start_time).round(2)}s) ==="
      totals.each { |k, v| @logger.info "  #{k}: #{v}" }
    end
  end

  # ────────────────────────────────────────────────────────────────────────────────
  private

  def import_episodes_sheet(sheet, sheet_name)
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

        # IMPORTANT: keep original order; participants & items are zipped by order
        participants = parse_participants(pick(row, :"participants_expanded"))
        brought_list = parse_items_list(pick(row, :items))         # no uniq; preserve order + dups
        given_list   = parse_items_list(pick(row, :"given_items")) # no uniq

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

        # BROUGHT: zip items to survivors by order; fallback to name→item if mismatch
        created = assign_brought_items(appearances, brought_list, pick(row, :"participants_expanded"), episode)
        counts[:items]            += created[:items]
        counts[:appearance_items] += created[:appearance_items]

        # GIVEN: attach to everyone (UI can de-dupe for display)
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

  def import_socials_sheet(sheet)
    header = sheet.row(1).map { |h| normalize_header_with_camel(h) }

    updated = 0
    unchanged = 0
    missing_name = 0
    not_found = 0
    errors = 0

    (2..sheet.last_row).each do |row_idx|
      begin
        raw = sheet.row(row_idx)
        row = header.zip(raw).to_h
        next if blank_row?(row)

        # Accept “FullName”, “Full Name”, “Name”, etc.
        name = pick(row, :name) || pick(row, :full_name)
        if name.blank?
          missing_name += 1
          next
        end

        survivor = find_survivor(name)
        unless survivor
          not_found += 1
          @logger.warn "Socials row #{row_idx}: survivor not found: #{name.inspect}"
          next
        end

        ig_url = normalize_instagram(pick(row, :instagram))
        fb_url = normalize_facebook(pick(row, :facebook))

        changes = {}
        changes[:instagram] = ig_url if ig_url.present? && survivor.instagram != ig_url
        changes[:facebook]  = fb_url if fb_url.present? && survivor.facebook  != fb_url

        if changes.any?
          survivor.update!(changes)
          updated += 1
        else
          unchanged += 1
        end
      rescue => e
        errors += 1
        @logger.error "Socials row #{row_idx} error: #{e.class} - #{e.message}"
      end
    end

    { updated:, unchanged:, missing_name:, not_found:, errors: }
  end

  # ── Upserts (cached) ───────────────────────────────────────────────────────────

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
      e.title                  = title
      e.air_date               = air_date
      e.scheduled_days         = scheduled_days
      e.participant_arrangement = arrangement
      e.type_modifiers         = type_mods
      e.location               = location
      e.notes                  = notes
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
      a.starting_psr        = starting_psr
      a.ending_psr          = ending_psr
      a.days_lasted         = days_lasted
      a.partner_replacement = partner_replacement
      a.role                = role
      a.notes               = notes
    end
  end

  def upsert_appearance_item(appearance, item, source, quantity)
    return nil if item.nil?
    AppearanceItem.find_or_create_by!(appearance:, item:, source:) do |ai|
      ai.quantity = quantity
    end
  end

  # ── "Brought" assignment ──────────────────────────────────────────────────────
  #
  # Zip items to survivors BY ORDER (preferred). If counts mismatch, fallback to
  # explicit pairs in Participants_Expanded like "Name (Machete)" or "Name - Machete".
  #
  # Returns { items: X, appearance_items: Y }

  def assign_brought_items(appearances, brought_list, participants_expanded_raw, episode)
    created = { items: 0, appearance_items: 0 }
    return created if appearances.blank? || brought_list.blank?

    # 1) Preferred: counts match → zip by order
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

    # 2) Fallback: explicit mapping
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

    # 3) Last resort: truncate to min size
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

  # ── Helpers / parsing ─────────────────────────────────────────────────────────

  def normalize_header(h)
    h.to_s.strip.downcase
      .gsub(/\s+/, "_")
      .gsub(/[()]/, "")
      .gsub(/-/, "_")
  end

  # CamelCase → snake_case also (handles "FullName")
  def normalize_header_with_camel(h)
    s = h.to_s.strip
    s = s.gsub(/\s+/, "_").gsub(/[()]/, "").gsub(/-/, "_")
    s = s.gsub(/([a-z\d])([A-Z])/, '\1_\2')
    s.downcase
  end

  def pick(row, key)
    aliases = {
      starting_psr: %w[starting_psr starting_psr_],
      ending_psr:   %w[ending_psr ending_psr_],
      given_items:  %w[given_items given_item given],
      name:         %w[name full_name fullname survivalist survivor],
      instagram:    %w[instagram ig instagram_url instagram_link instagram_handle],
      facebook:     %w[facebook fb facebook_url facebook_link facebook_page]
    }
    keys = [key.to_s] + Array(aliases[key]).to_a
    keys.find { |k| row.key?(k) }.then { |k| k ? row[k] : nil }
  end

  def blank_row?(row)
    row.values.compact.map(&:to_s).all? { |s| s.strip.empty? }
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
    return nil if str.empty?
    BigDecimal(str) rescue nil
  end

  # Robust AirDate parser: Date/DateTime/Time, Excel serials, or strings.
  def to_date_or_nil(v)
    return nil if v.nil?
    case v
    when Date      then v
    when DateTime  then v.to_date
    when Time      then v.to_date
    when Numeric   then excel_serial_to_date(v)
    else
      s = v.to_s.strip
      return nil if s.empty?
      Date.parse(s)
    end
  rescue
    nil
  end

  # Excel 1900 date system (as commonly used by .xlsx); 1899-12-30 accounts for Excel's leap bug.
  def excel_serial_to_date(n)
    base = Date.new(1899, 12, 30)
    base + n.to_i
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

  # Keep order and duplicates (needed to zip brought items by order)
  def parse_items_list(raw)
    s = raw.to_s
    return [] if s.strip.empty?
    s.split(/[,&]| and /i)
     .map { |name| canonical_item_name(name) }
     .reject(&:blank?)
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

  def find_survivor(name)
    nm = name.to_s.strip.squeeze(" ")
    return nil if nm.blank?
    Survivor.find_by(full_name: nm) || Survivor.where("full_name ILIKE ?", nm).first
  end

  def normalize_instagram(v)
    s = clean_urlish(v)
    return nil if s.blank?
    return s if s =~ %r{\Ahttps?://}i
    handle = s.sub(/\A@/, "")
    return nil if handle.blank?
    "https://instagram.com/#{handle}"
  end

  def normalize_facebook(v)
    s = clean_urlish(v)
    return nil if s.blank?
    return s if s =~ %r{\Ahttps?://}i
    handle = s.sub(/\A@/, "")
    return nil if handle.blank?
    "https://facebook.com/#{handle}"
  end

  def clean_urlish(v)
    s = v.to_s.strip
    return "" if s.empty? || s =~ /\A(?:n\/a|na|none|null|nil|-\s*)\z/i
    s.gsub(/\A["']|["']\z/, "")
  end

  def wipe_data!
    @logger.warn "WIPING existing N&A data (episodes/appearances/items/locations/seasons/series/survivors)…"
    # delete in FK-safe order
    AppearanceItem.delete_all
    Appearance.delete_all
    Episode.delete_all
    Location.delete_all
    Season.delete_all
    Series.delete_all
    Item.delete_all
    Survivor.delete_all
    @logger.warn "Wipe complete."
  end

  def monotime
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
