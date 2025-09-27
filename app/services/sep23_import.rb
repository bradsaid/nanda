# app/services/sep23_import.rb
# frozen_string_literal: true
require "roo"
require "csv"
require "bigdecimal/util"

class Sep23Import
  # Import only sheets that actually exist in the workbook.
  SHEETS = [
    "Regular",
    "Solo",
    "XL",
    "Frozen",
    "Alone",
    "Naked and Afraid Savage",
    "Castaways",
    "Last One Standing",
    "Apocalypse"
  ].freeze

  # Series that should be treated as continuous
  CONTINUOUS_SERIES_NAMES = [
    "naked and afraid: solo",
    "naked and afraid xl",
    "naked and afraid savage",
    "naked and afraid castaways",
    "naked and afraid last one standing",
    "naked and afraid apocalypse"
  ].freeze

  DEFAULT_XLSX = "/Users/bradsaid/Desktop/NakedAndAfraidDB latest.xlsx"

  def initialize(path = DEFAULT_XLSX, dry_run: false,
                 verbose: false, only: nil, limit: 0, **_opts)
    @path     = path.to_s
    @dry_run  = dry_run
    @verbose  = verbose

    @only_filter = only&.to_s&.downcase&.strip
    @limit       = limit.to_i

    @stats    = Hash.new(0)
    @warnings = []
  end

  def run!
    raise "XLSX not found: #{@path}" unless File.exist?(@path)
    puts "[INFO] Using: #{@path}" if @verbose

    ActiveRecord::Base.transaction do
      import_survivor_directory

      available = book.sheets.map(&:to_s)
      to_import = SHEETS & available
      missing   = SHEETS - to_import
      puts "[INFO] Episode sheets to import: #{to_import.join(', ')}" if @verbose
      puts "[WARN] Missing sheets (skipped): #{missing.join(', ')}" if @verbose && missing.any?

      # ensure all Series records exist and continuous flags are set before deeper import
      ensure_series_records!(to_import)

      to_import.each { |s| import_episode_sheet(s) }

      raise ActiveRecord::Rollback if @dry_run
    end

    summarize!
  end

  private

  # --------- helpers ---------
  def book
    @book ||= Roo::Spreadsheet.open(@path)
  end

  def sheet(name) = book.sheet(name)

  def norm(s) = s.to_s.strip

  def down(s) = s.to_s.strip.downcase

  def split_list(s)
    return [] if s.nil?
    s.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def parse_date(v)
    return v if v.is_a?(Date)
    Date.parse(v.to_s) rescue nil
  end

  def boolish(v)
    return nil if v.nil?
    %w[1 true yes y t].include?(v.to_s.strip.downcase)
  end

  def within_0_10?(v) = v && v >= 0 && v <= 10

  def parse_psrs_aligned(raw_psrs, participant_count)
    vals =
      split_list(raw_psrs).map do |token|
        if token =~ /\A\d+(?:\.\d+)?\z/
          BigDecimal(token)
        else
          num = token.to_s[/\d+(?:\.\d+)?/]
          num ? BigDecimal(num) : nil
        end
      end
    (vals + [nil] * participant_count)[0...participant_count]
  end

  # --------- Series pre-pass ---------
  def ensure_series_records!(sheets)
    sheets.each do |sheet_name|
      sh = sheet(sheet_name)
      header = sh.row(1).map!(&:to_s)
      si = header.index("Series")
      next unless si

      (2..sh.last_row).each do |r|
        raw = sh.row(r)[si]
        next if raw.blank?
        series = Series.find_or_create_by!(name: norm(raw))
        if CONTINUOUS_SERIES_NAMES.include?(down(series.name)) && !series.continuous_story
          series.update!(continuous_story: true)
        end
      end
    end
  end

  # --------- Survivor directory ---------
  def import_survivor_directory
    sh = sheet("Survivalist Dashboard")
    header = sh.row(1).map!(&:to_s)
    col = ->(name) { header.index(name) }

    processed = 0
    (2..sh.last_row).each do |r|
      row = sh.row(r)

      full_name = row[col.call("FullName")]
      next if full_name.blank?

      if @only_filter.present? && !full_name.to_s.downcase.include?(@only_filter)
        next
      end

      instagram = row[col.call("Instagram")].presence
      facebook  = row[col.call("Facebook")].presence
      website   = row[col.call("Website")].presence
      youtube   = row[col.call("YouTube")].presence
      cameo     = row[col.call("Cameo")].presence
      onlyfans  = row[col.call("Only Fans")].presence

      s = Survivor.find_or_create_by!(full_name: norm(full_name))
      attrs = {
        instagram:,
        facebook:,
        website:,
        youtube:,
        cameo:,
        onlyfans:
      }.compact
      s.update!(attrs) if attrs.any?

      @stats[:survivors_from_directory] += 1
      processed += 1
      break if @limit > 0 && processed >= @limit
    end
  end

  # --------- Episodes / Appearances / Items ---------
  def import_episode_sheet(sheet_name)
    return import_solo_sheet if sheet_name.to_s.strip == "Solo"
    import_standard_episode_sheet(sheet_name)
  end

  def import_standard_episode_sheet(sheet_name)
    sh = sheet(sheet_name)
    header = sh.row(1).map!(&:to_s)
    at = ->(row, colname) { row[header.index(colname)] if header.include?(colname) }

    (2..sh.last_row).each do |r|
      row = sh.row(r)

      series_name  = at.call(row, "Series")
      season_num   = at.call(row, "Season")
      ep_num       = at.call(row, "Number")
      title        = at.call(row, "Title")
      air_date     = at.call(row, "AirDate")
      sched_days   = at.call(row, "ScheduledDays")
      arrangement  = at.call(row, "ParticipantArrangement")
      type_mod     = at.call(row, "TypeModifiers")
      country      = at.call(row, "Location")
      partner_rep  = at.call(row, "PartnerReplacement")
      start_psr    = at.call(row, "Starting PSR")
      end_psr      = at.call(row, "Ending PSR")
      notes        = at.call(row, "Notes")
      items_csv    = at.call(row, "Items")
      given_csv    = at.call(row, "Given Items")
      participants = split_list(at.call(row, "Participants_Expanded"))

      next if [series_name, season_num, ep_num, title, country].any?(&:blank?)

      series = Series.find_or_create_by!(name: norm(series_name))
      if CONTINUOUS_SERIES_NAMES.include?(down(series.name)) && !series.continuous_story
        series.update!(continuous_story: true)
      end

      season = Season.find_or_create_by!(series:, number: season_num.to_i)
      season.update!(year: season.year || parse_date(air_date)&.year)

      location = Location.find_or_create_by!(country: norm(country))

      episode = Episode.find_or_create_by!(season:, number_in_season: ep_num.to_i) do |e|
        e.title                   = norm(title)
        e.air_date                = parse_date(air_date)
        e.scheduled_days          = sched_days.to_i if sched_days
        e.participant_arrangement = arrangement
        e.type_modifiers          = type_mod
        e.location                = location
        e.notes                   = notes if notes.present?
      end
      episode.update!(location:) if episode.location_id != location.id

      starting_psrs = parse_psrs_aligned(start_psr, participants.length)
      ending_psrs   = parse_psrs_aligned(end_psr,   participants.length)

      participants.each_with_index do |full_name, idx|
        surv = Survivor.find_or_create_by!(full_name: norm(full_name))

        # IMPORTANT: create Appearance with a location so validations pass
        app  = Appearance.find_or_create_by!(survivor: surv, episode: episode, location: location)

        sp = starting_psrs[idx]
        ep = ending_psrs[idx]

        updates = {}
        updates[:starting_psr] = sp if within_0_10?(sp)
        updates[:ending_psr]   = ep if within_0_10?(ep)
        pr = boolish(partner_rep)
        updates[:partner_replacement] = pr unless pr.nil?
        updates[:notes] = [app.notes, notes.presence].compact_blank.uniq.join("\n") if notes.present?

        app.update!(updates) if updates.any?
      end

      # Brought items: one per participant in these sheets
      item_names = split_list(items_csv)
      if item_names.any?
        participants.each_with_index do |full_name, idx|
          next unless item_names[idx].present?
          surv = Survivor.find_by(full_name: norm(full_name))
          app  = Appearance.find_by(survivor: surv, episode: episode)
          item = Item.find_or_create_by!(name: norm(item_names[idx]))
          AppearanceItem.find_or_create_by!(appearance: app, item:, source: "brought")
        end
      end

      # Given items: applied to all appearances in the episode
      given_names = split_list(given_csv)
      if given_names.any?
        episode.appearances.find_each do |app|
          given_names.each do |gname|
            item = Item.find_or_create_by!(name: norm(gname))
            AppearanceItem.find_or_create_by!(appearance: app, item:, source: "given")
          end
        end
      end

      @stats[:"episodes_#{sheet_name.downcase}"] += 1
    end
  end

  # Solo special case:
  # - Episodes are defined in the top block.
  # - Each survivor (bottom block) has ONE location and THREE brought items.
  # - Every Solo episode contains ALL Solo survivors; survivor location is stored on the appearance.
  def import_solo_sheet
    sh      = sheet("Solo")
    header  = sh.row(1).map!(&:to_s)
    at = ->(row, colname) { row[header.index(colname)] if header.include?(colname) }

    episode_rows = []
    cast_rows    = []

    (2..sh.last_row).each do |r|
      row = sh.row(r)
      season  = at.call(row, "Season")
      number  = at.call(row, "Number")
      namecsv = at.call(row, "Participants_Expanded").to_s
      names   = split_list(namecsv)

      if season.present? && number.present?
        episode_rows << row
      elsif names.size == 1 && namecsv.present?
        cast_rows << row
      end
    end

    if episode_rows.empty? || cast_rows.empty?
      @warnings << "[Solo] Could not find both episode rows and cast rows; episodes=#{episode_rows.size}, cast=#{cast_rows.size}"
      return
    end

    # Series/Season from first episode row
    series_name = at.call(episode_rows.first, "Series")
    season_num  = at.call(episode_rows.first, "Season").to_i
    air_date0   = parse_date(at.call(episode_rows.first, "AirDate"))

    series = Series.find_or_create_by!(name: norm(series_name))
    if CONTINUOUS_SERIES_NAMES.include?(down(series.name)) && !series.continuous_story
      series.update!(continuous_story: true)
    end

    season = Season.find_or_create_by!(series:, number: season_num)
    season.update!(year: season.year || air_date0&.year)

    # Build/find episodes (do NOT set episode.location; Solo has per-appearance locations)
    episodes = episode_rows.map do |erow|
      ep_num       = at.call(erow, "Number").to_i
      title        = norm(at.call(erow, "Title"))
      air_date     = parse_date(at.call(erow, "AirDate"))
      sched_days   = at.call(erow, "ScheduledDays")
      arrangement  = at.call(erow, "ParticipantArrangement")
      type_mod     = at.call(erow, "TypeModifiers")
      ep_notes     = at.call(erow, "Notes")

      Episode.find_or_create_by!(season:, number_in_season: ep_num) do |e|
        e.title                   = title
        e.air_date                = air_date
        e.scheduled_days          = sched_days.to_i if sched_days
        e.participant_arrangement = arrangement
        e.type_modifiers          = type_mod
        e.notes                   = ep_notes if ep_notes.present?
      end
    end

    # Build per-survivor info with their own location + items
    survivors = cast_rows.map do |crow|
      full_name = norm(split_list(at.call(crow, "Participants_Expanded")).first)
      country   = norm(at.call(crow, "Location"))
      start_psr = at.call(crow, "Starting PSR")
      end_psr   = at.call(crow, "Ending PSR")
      items_csv = at.call(crow, "Items")
      given_csv = at.call(crow, "Given Items")

      surv = Survivor.find_or_create_by!(full_name: full_name)
      loc  = Location.find_or_create_by!(country: country.presence || "Unknown")

      sp  = (start_psr.to_s[/\d+(?:\.\d+)?/]; sp &&= BigDecimal(sp))
      epv = (end_psr.to_s[/\d+(?:\.\d+)?/];    epv &&= BigDecimal(epv))

      {
        survivor: surv,
        location: loc,
        starting_psr: sp,
        ending_psr:   epv,
        brought: split_list(items_csv).uniq,
        given:   split_list(given_csv).uniq
      }
    end

    # Every Solo episode gets an appearance for every Solo survivor.
    # Create with location set BEFORE save so validations pass.
    episodes.each do |episode|
      survivors.each do |h|
        app = Appearance.find_or_initialize_by(survivor: h[:survivor], episode: episode)
        app.location ||= h[:location]
        app.role = "solo"
        app.starting_psr = h[:starting_psr] if within_0_10?(h[:starting_psr])
        app.ending_psr   = h[:ending_psr]   if within_0_10?(h[:ending_psr])
        app.save!

        h[:brought].each do |iname|
          next if iname.blank?
          item = Item.find_or_create_by!(name: norm(iname))
          AppearanceItem.find_or_create_by!(appearance: app, item:, source: "brought")
        end

        h[:given].each do |gname|
          next if gname.blank?
          item = Item.find_or_create_by!(name: norm(gname))
          AppearanceItem.find_or_create_by!(appearance: app, item:, source: "given")
        end
      end
    end

    @stats[:episodes_solo] += episodes.size
  end

  # --------- summary ---------
  def summarize!
    puts "=== Import summary ==="
    @stats.sort.each { |k, v| puts "#{k}: #{v}" }
    @warnings.each { |w| puts "- #{w}" } if @warnings.any?
  end
end
