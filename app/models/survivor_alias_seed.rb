# Curated search aliases for survivors, applied by the SeedSurvivorAliases migration (and
# safe to re-run any time via SurvivorAliasSeed.apply!).
#
# Source: Google Search Console queries (12 months). Only HIGH-CONFIDENCE entries are listed:
# spelling variants of the same name, accent variants, and a few nicknames people search
# for. Bare first names that could belong to more than one survivor ("ali", "joe", "sam",
# "lily", "marina", "teal"...) are deliberately NOT here; add those by hand in the admin
# form if you decide they are safe.
#
# Entries are matched by slug first, then by full name; a survivor that does not exist (or
# was renamed) is skipped and reported, never an error.
class SurvivorAliasSeed
  ALIASES = [
    { slug: "ana-lis-pitter",   name: "Ana Lis Pitter",
      aliases: ["Analis", "Analis Pitter", "Anna Lis", "Anna Lis Pitter", "Annalis", "Annalise", "Analise",
                "Annalize", "Analisa", "Ana Lise", "Ana Liz", "Ana Liz Pitter", "Ana Lisa", "Ana Pitter"] },
    { slug: "allison-frueh",    name: "Allison Frueh",
      aliases: ["Ally", "Ally Frueh", "Allison Wanderland", "allisonwanderland3", "Allison Freuh", "Ally Freuh", "Alison Freuh"] },
    { slug: "gary-golding",     name: "Gary Golding",
      aliases: ["Gary Goulding"] },
    { slug: "jarrell-banks",    name: "Jarrell Banks",
      aliases: ["Jarrel Banks", "Jarell Banks", "Jerrell Banks", "Jarrel", "Jarell", "Jerrell"] },
    { slug: "rene-murad",       name: "Rene Murad",
      aliases: ["René Murad", "Renee Murad"] },
    { slug: "marina-lara-fukushima", name: "Marina Lara Fukushima",
      aliases: ["Marina Fukushima", "Marina Fukishima"] },
    { slug: "malu-beyonce",     name: "Malu Beyonce",
      aliases: ["Malu Beyoncé"] },
    { slug: "melissa-miller",   name: "Melissa Miller",
      aliases: ["Melissa Backwoods", "Melissa Backwoods Miller", "Mellisa Miller"] },
    { slug: "jonny-yates",      name: "Jonny Yates",
      aliases: ["Johnny Yates"] },
    { slug: "lilly-jammerbund", name: "Lilly Jammerbund",
      aliases: ["Survival Lilly"] },
    { slug: "jamie-frizzell",   name: "Jamie Frizzell",
      aliases: ["Jamie Wildman Frizzell"] },
    { slug: "bob-catfish-rabon", name: "Bob Catfish Rabon",
      aliases: ["Catfish Bob"] },
    { slug: "paolo-di-girolamo", name: "Paolo Di Girolamo",
      aliases: ["Paolo DiGirolamo"] },
    { slug: "tyler-whitney",    name: "Tyler Whitney",
      aliases: ["Tyler Whitley"] }
  ].freeze

  # Merges each entry's aliases into the matching survivor's existing aliases (nothing is
  # removed; order: what was already there, then new ones). Returns
  # { updated:, unchanged:, missing: [slugs] }.
  def self.apply!(entries = ALIASES)
    result = { updated: 0, unchanged: 0, missing: [] }
    entries.each do |entry|
      survivor = Survivor.find_by(slug: entry[:slug]) || Survivor.find_by(full_name: entry[:name])
      unless survivor
        result[:missing] << entry[:slug]
        next
      end
      merged = Survivor.clean_aliases(Array(survivor.aliases) + entry[:aliases], full_name: survivor.full_name)
      if merged == Array(survivor.aliases)
        result[:unchanged] += 1
      else
        # update_columns: no callbacks, and updated_at (the page's "Last updated") stays put.
        survivor.update_columns(aliases: merged)
        result[:updated] += 1
      end
    end
    result
  end
end
