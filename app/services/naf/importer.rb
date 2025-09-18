# app/services/naf/importer.rb
# frozen_string_literal: true
require "roo"
require "csv"
require "bigdecimal/util"

module Naf
  class Importer
    SHEETS  = ["Regular", "Solo", "XL", "Frozen"].freeze
    SOURCES = %w[brought given found earned foraged].freeze

    def initialize(path, dry_run: false)
      @path     = path.to_s
      @dry_run  = dry_run
      @stats    = Hash.new(0)
      @warnings = []
    end

    def run!
      ActiveRecord::Base.transaction do
        import_survivor_directory
        SHEETS.each { |sheet| import_episode_sheet(sheet) }
        raise ActiveRecord::Rollback if @dry_run
      end
      summarize!
    end

    private

    # ---------------- IO ----------------
    def book
      @book ||= Roo::Spreadsheet.open(@path)
    end

    def sheet(name) = book.sheet(name)

    # ---------------- generic helpers ----------------
    def norm(s) = s.to_s.strip

    def split_list(s)
      return [] if s.nil?
      s.to_s.split(",").map { |e| e.strip }.reject(&:empty?)
    end

    def parse_date(v)
      return v if v.is_a?(Date)
      Date.parse(v.to_s) rescue nil
    end

    def boolish(v)
      return nil if v.nil?
      %w[1 true yes y t].include?(v.to_s.strip.downcase)
    end

    # Parse a comma-separated PSR list like "5.8, 7.6" into BigDecimal,
    # preserve order, and align to participant count (pad nils / truncate extras).
    def parse_psrs_aligned(raw_psrs, participant_count)
      vals =
        split_list(raw_psrs).map do |token|
          # accept decimals like 5, 5.7, 10 ; reject non-numeric tokens
          if token =~ /\A\d+(?:\.\d+)?\z/
            BigDecimal(token)
          else
            # last-ditch: pull first numeric from token
            num = token.to_s[/\d+(?:\.\d+)?/]
            num ? BigDecimal(num) : nil
          end
        end

      # align by index to survivors: pad/truncate
      aligned = (vals + [nil] * participant_count)[0...participant_count]
      aligned
    end

    def within_0_10?(v) = v && v >= 0 && v <= 10

    # ---------------- Survivor directory ----------------
    # Sheet: "Survivalist Dashboard" with columns: FullName, Instagram, Facebook, Website
    def import_survivor_directory
      sh = sheet("Survivalist Dashboard")
      header = sh.row(1).map!(&:to_s)
      col = ->(name) { header.index(name) }

      (2..sh.last_row).each do |r|
        row = sh.row(r)
        full_name = row[col.call("FullName")]
        next if full_name.blank?

        s = Survivor.find_or_create_by!(full_name: norm(full_name))
        attrs = {
          instagram: row[col.call("Instagram")].presence,
          facebook:  row[col.call("Facebook")].presence,
          website:   row[col.call("Website")].presence
        }.compact
        s.update!(attrs) if attrs.any?
        @stats[:survivors_from_directory] += 1
      end
    end

    # ---------------- Episodes/Appearances/Items ----------------
    def import_episode_sheet(sheet_name)
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

        # required fields per your schema
        next if [series_name, season_num, ep_num, title, country].any?(&:blank?)

        # series/season
        series = Series.find_or_create_by!(name: norm(series_name))
        season = Season.find_or_create_by!(series:, number: season_num.to_i)
        season.update!(year: season.year || parse_date(air_date)&.year)

        # location (country-level in workbook; region/site unknown here)
        location = Location.find_or_create_by!(country: norm(country))

        # episode
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

        # appearances (create in order of participants)
        starting_psrs = parse_psrs_aligned(start_psr, participants.length)
        ending_psrs   = parse_psrs_aligned(end_psr,   participants.length)

        if starting_psrs.length != participants.length || ending_psrs.length != participants.length
          @warnings << "#{sheet_name} R#{r} '#{title}': PSR count misalignment; aligned by index."
        end

        participants.each_with_index do |full_name, idx|
          surv = Survivor.find_or_create_by!(full_name: norm(full_name))
          app  = Appearance.find_or_create_by!(survivor: surv, episode: episode)

          sp = starting_psrs[idx]
          ep = ending_psrs[idx]

          updates = {}
          # strictly preserve decimals like 5.7; only write if valid 0..10
          if within_0_10?(sp)
            updates[:starting_psr] = sp
          elsif sp
            @warnings << "#{sheet_name} R#{r} '#{title}': starting_psr=#{sp.to_s('F')} out of 0..10 — skipped."
          end

          if within_0_10?(ep)
            updates[:ending_psr] = ep
          elsif ep
            @warnings << "#{sheet_name} R#{r} '#{title}': ending_psr=#{ep.to_s('F')} out of 0..10 — skipped."
          end

          pr = boolish(partner_rep)
          updates[:partner_replacement] = pr unless pr.nil?
          updates[:notes] = [app.notes, notes.presence].compact_blank.uniq.join("\n") if notes.present?

          app.update!(updates) if updates.any?
        end

        # brought items — position aligned 1:1 with participants
        item_names = split_list(items_csv)
        if item_names.any?
          if item_names.length != participants.length
            @warnings << "#{sheet_name} R#{r} '#{title}': participants=#{participants.length} items=#{item_names.length} — aligning by index, ignoring extras/missing."
          end
          participants.each_with_index do |full_name, idx|
            next unless item_names[idx].present?
            surv = Survivor.find_by(full_name: norm(full_name))
            app  = Appearance.find_by(survivor: surv, episode: episode)
            item = Item.find_or_create_by!(name: norm(item_names[idx]))
            ai   = AppearanceItem.find_or_initialize_by(appearance: app, item:, source: "brought")
            ai.quantity = (ai.quantity || 0) + 1
            ai.save!
          end
        end

        # given items — shared; attach to each appearance, but when aggregating totals
        # you must COUNT DISTINCT episode_id to avoid double-counting.
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

    # ---------------- summary ----------------
    def summarize!
      puts "=== Import summary ==="
      @stats.sort.each { |k, v| puts "#{k}: #{v}" }
      if @warnings.any?
        puts "\n=== Warnings ==="
        @warnings.each { |w| puts "- #{w}" }
      end
      puts "\nNOTE: 'Given Items' are shared; when totaling, count DISTINCT episode_id for source='given'."
    end
  end
end
