# lib/tasks/naf_swap.rake
namespace :naf do
  desc "Swap XL S10 E1–8 appearances from one survivor to another. Default: Olesen -> Martinez (dry-run). Use COMMIT=1 to write."
  task swap_xl10_nathan: :environment do
    from_name   = ENV["FROM"]   || "Nathan Olesen"
    to_name     = ENV["TO"]     || "Nathan Martinez"
    # NOTE: your DB most likely has 'Naked and Afraid XL' (no ampersand)
    series_name = ENV["SERIES"] || "Naked and Afraid XL"
    season_no   = (ENV["SEASON"] || "10").to_i
    eps_arg     = ENV["EPS"]    || "1-8"
    commit      = ENV["COMMIT"] == "1"
    merge_ok    = ENV["MERGE"]  == "1"

    ep_numbers =
      if eps_arg.include?("-")
        a, b = eps_arg.split("-", 2).map(&:to_i); (a..b).to_a
      else
        eps_arg.split(",").map(&:to_i)
      end

    # ---- Robust series finder ----
    series =
      if ENV["SERIES_ID"].present?
        Series.find(ENV["SERIES_ID"])
      else
        variants = [
          series_name,
          series_name.gsub(/\s*&\s*/i, " and "),
          series_name.gsub(/\sand\s/i, " & ")
        ].uniq

        found = variants.lazy.map { |n| Series.find_by(name: n) }.find(&:present?)
        found ||= Series.where("name ILIKE ?", "%#{series_name}%").first
        found ||= Series.where("name ILIKE ?", "%Naked%Afraid%XL%").first

        unless found
          available = Series.order(:id).limit(50).pluck(:id, :name).map { |id, n| "#{id}: #{n}" }.join(" | ")
          raise ActiveRecord::RecordNotFound, "Series not found. Tried: #{variants.join(' | ')}. Available (first 50): #{available}. Override with SERIES or SERIES_ID."
        end
        found
      end

    season = Season.find_by!(series_id: series.id, number: season_no)
    episodes = Episode.where(season_id: season.id, number_in_season: ep_numbers)

    from_survivor = Survivor.find_by!(full_name: from_name)
    to_survivor   = Survivor.find_by!(full_name: to_name)

    puts "Plan:"
    puts "  Series: #{series.name} (id=#{series.id})"
    puts "  Season: #{season_no} (id=#{season.id})"
    puts "  Episodes: #{ep_numbers.join(', ')}  count=#{episodes.count}"
    puts "  FROM: #{from_survivor.full_name} (id=#{from_survivor.id})"
    puts "  TO:   #{to_survivor.full_name} (id=#{to_survivor.id})"
    puts "  Mode: #{commit ? 'WRITE (COMMIT)' : 'DRY-RUN'}"
    puts "  Merge if target exists in an episode: #{merge_ok ? 'YES' : 'NO (raise)'}"
    puts

    total_moved = 0
    total_merged = 0
    details = []

    perform = lambda do |persist:|
      episodes.find_each do |ep|
        old_appr = Appearance.find_by(survivor_id: from_survivor.id, episode_id: ep.id)
        next unless old_appr

        target_appr = Appearance.find_by(survivor_id: to_survivor.id, episode_id: ep.id)

        if target_appr
          unless merge_ok
            msg = "Episode #{ep.number_in_season}: target appearance already exists; rerun with MERGE=1 to merge."
            raise msg if persist
            details << "DRY: #{msg}"
            next
          end

          if persist
            old_appr.appearance_items.find_each do |ai|
              dest = target_appr.appearance_items.find_or_initialize_by(item_id: ai.item_id, source: ai.source)
              dest.quantity = (dest.quantity || 0) + (ai.quantity || 0)
              dest.notes = [dest.notes, ai.notes].compact.reject(&:blank?).uniq.join(" | ").presence
              dest.save!
            end

            %i[starting_psr ending_psr days_lasted result role partner_replacement notes location_id].each do |attr|
              target_appr[attr] = old_appr[attr] if target_appr[attr].blank? && old_appr[attr].present?
            end
            target_appr.save!
            old_appr.destroy!
          end

          total_merged += 1
          details << "#{persist ? '' : 'DRY: '}Episode #{ep.number_in_season}: merged items into existing target; removed old."
        else
          if persist
            old_appr.update!(survivor_id: to_survivor.id) # keeps items via same appearance_id
          end
          total_moved += 1
          details << "#{persist ? '' : 'DRY: '}Episode #{ep.number_in_season}: reassigned appearance to #{to_survivor.full_name}."
        end
      end
    end

    if commit
      ActiveRecord::Base.transaction { perform.call(persist: true) }
    else
      perform.call(persist: false)
    end

    puts details.join("\n")
    puts
    puts "Summary:"
    puts "  Reassigned: #{total_moved}"
    puts "  Merged:     #{total_merged}"
    puts
    puts "Done. #{commit ? '' : 'No changes written (dry-run). Use COMMIT=1 to apply.'}"
  end
end
