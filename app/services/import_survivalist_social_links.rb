# frozen_string_literal: true
require "roo"
require "csv" # Ruby 3.4+

class ImportSurvivalistSocialLinks
  DEFAULT_SHEET = "Survivalist Dashboard"

  def initialize(path:, sheet_name: DEFAULT_SHEET, dry_run: false, logger: Rails.logger)
    @path       = path
    @sheet_name = sheet_name
    @dry_run    = dry_run
    @logger     = logger
  end

  def call
    xlsx  = Roo::Spreadsheet.open(@path)
    sheet = pick_sheet(xlsx)

    @logger.info "Importing socials from '#{@sheet_name}' in #{@path}"

    updated = 0
    unchanged = 0
    missing_name = 0
    not_found = 0
    row_errors = 0

    ActiveRecord::Base.transaction do
      header = sheet.row(1).map { |h| norm(h) }

      (2..sheet.last_row).each do |row_idx|
        begin
          raw = sheet.row(row_idx)
          row = header.zip(raw).to_h
          next if blank_row?(row)

          name = pick(row, :name)
          if name.blank?
            missing_name += 1
            next
          end

          survivor = find_survivor(name)
          unless survivor
            not_found += 1
            @logger.warn "Row #{row_idx}: survivor not found: #{name.inspect}"
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
            @logger.info "Row #{row_idx}: updated #{survivor.full_name} (#{changes.keys.join(", ")})"
          else
            unchanged += 1
          end
        rescue => e
          row_errors += 1
          @logger.error "Row #{row_idx} error: #{e.class} - #{e.message}"
        end
      end

      if @dry_run
        @logger.info "DRY RUN — rolling back"
        raise ActiveRecord::Rollback
      end
    end

    @logger.info "=== Social import summary ==="
    @logger.info "updated: #{updated}, unchanged: #{unchanged}, not_found: #{not_found}, missing_name: #{missing_name}, errors: #{row_errors}"
  end

  private

  def pick_sheet(xlsx)
    if xlsx.sheets.include?(@sheet_name)
      return xlsx.sheet(@sheet_name)
    end
    alt = xlsx.sheets.find { |n| n.downcase.include?("survivalist") && n.downcase.include?("dashboard") }
    @sheet_name = alt || xlsx.sheets.first
    xlsx.sheet(@sheet_name)
  end

  # --- helpers ---

  def norm(v)
    s = v.to_s.strip
    s = s.gsub(/\s+/, "_").gsub(/[()]/, "").gsub(/-/, "_")
    s = s.gsub(/([a-z\d])([A-Z])/, '\1_\2') # FullName -> Full_Name
    s.downcase                                # => "full_name"
  end

  def blank_row?(row)
    row.values.compact.map(&:to_s).all? { |s| s.strip.empty? }
  end

  def pick(row, field)
    aliases = {
      name:      %w[survivalist survivor full_name fullname name],
      instagram: %w[instagram ig instagram_url instagram_link instagram_handle],
      facebook:  %w[facebook fb facebook_url facebook_link facebook_page]
    }
    key = Array(aliases[field] || field.to_s).find { |k| row.key?(k) }
    row[key]
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
    return "" if s.empty?
    return "" if s =~ /\A(?:n\/a|na|none|null|nil|-\s*)\z/i
    s.gsub(/\A["']|["']\z/, "")
  end
end
