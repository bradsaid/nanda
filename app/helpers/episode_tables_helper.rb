# Row/column building for the tables on an episode page, so the page shows only what is
# known: a column with no value in any row is left out, and a table with no rows is omitted
# (no "—" placeholders). A cell that is blank in a column other tables rows do fill is rendered
# empty; on phones the stacked-table CSS hides empty cells (`td:empty`).
module EpisodeTablesHelper
  # The keys (in the order given) that have a value in at least one row. Rows are hashes.
  def visible_columns(rows, *keys)
    keys.select { |key| rows.any? { |row| row[key].present? } }
  end

  # One hash per participant, alphabetical by first name like the old table:
  # appearance, survivor, role, psr ("2 → 7"), days, result, weight_loss ("12 lbs"),
  # brought and given (safe HTML lists of item labels, nil when none). `hoisted_ids` are the
  # appearance items already shown once in the "Given to each team" banner.
  def participant_rows(appearances, episode:, shelf: nil, hoisted_ids: [])
    appearances
      .select(&:survivor)
      .sort_by { |ap| ap.survivor.full_name.to_s.split.first.to_s.downcase }
      .map do |a|
        s = a.survivor
        labels = lambda do |source|
          items = a.appearance_items.select { |ai| ai.source == source && !(source == "given" && hoisted_ids.include?(ai.id)) }
          list  = items.filter_map { |ai| appearance_item_label(ai, survivor: s, episode: episode, shelf: shelf) }
          safe_join(list, ", ").presence
        end
        {
          appearance: a, survivor: s,
          role: a.role.presence,
          psr: [a.starting_psr, a.ending_psr].compact.join(" → ").presence,
          days: a.days_lasted.presence,
          result: a.result.presence,
          weight_loss: (a.weight_loss.present? ? "#{a.weight_loss.to_i} lbs" : nil),
          brought: labels.call("brought"),
          given: labels.call("given")
        }
      end
  end

  def trap_rows(traps)
    traps.map do |trap|
      catches = trap.food_sources.map { |fs| fs.quantity.to_i > 1 ? "#{fs.name.titleize} ×#{fs.quantity}" : fs.name.titleize }
      { trap: trap, builders: trap.builders&.to_a.presence, result: trap.result.presence, caught: catches.join(", ").presence }
    end
  end

  def food_source_rows(food_sources)
    food_sources.map do |fs|
      tools = []
      if fs.episode_trap
        tname = fs.episode_trap.trap_type.to_s
        tools << (tname.match?(/(trap|basket|net)\z/i) ? tname : "#{tname} Trap")
      end
      tools << fs.tools_used if fs.tools_used.present?
      { food: fs, method: fs.method&.humanize.presence, tools: tools.join(" with ").presence }
    end
  end

  def medical_call_rows(calls)
    calls.map { |mc| { call: mc, survivor: mc.survivor, reason: mc.reason.presence, notes: mc.notes.presence } }
  end

  def bushcraft_rows(items)
    items.map { |bi| { item: bi, materials: bi.materials.presence, builders: bi.builders&.to_a.presence, notes: bi.notes.presence } }
  end
end
