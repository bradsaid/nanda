module Forum
  # Typeahead source for @survivor and #episode mentions in the composer.
  # Read-only JSON; the forum gate in BaseController still applies.
  class MentionsController < BaseController
    LIMIT = 8

    def index
      query = params[:q].to_s.strip
      results =
        if query.length.zero?
          []
        elsif params[:type].to_s == "episode"
          episodes(query)
        else
          survivors(query)
        end

      render json: { results: results }
    end

    private

    # People type "@mattwright" as one word, so match on a form with the
    # spaces, hyphens and apostrophes stripped out of both sides.
    def squashed(value) = value.to_s.downcase.gsub(/[^a-z0-9]/, "")

    def squash_sql(column)
      "REGEXP_REPLACE(LOWER(#{column}), '[^a-z0-9]', '', 'g')"
    end

    def survivors(query)
      needle = squashed(query)
      return [] if needle.blank?

      Survivor
        .where("#{squash_sql('full_name')} LIKE ?", "%#{needle}%")
        .order(Arel.sql("POSITION(#{ActiveRecord::Base.connection.quote(needle)} IN #{squash_sql('full_name')}), full_name"))
        .limit(LIMIT)
        .map { |s| { label: s.full_name, sub: "Survivalist", path: survivor_path(s) } }
    end

    def episodes(query)
      scope = Episode.includes(:season).joins(:season)

      # "s12e03" should find that episode directly, as well as by title.
      if (m = query.match(/\As(\d+)\s*e(\d+)\z/i))
        scope = scope.where(seasons: { number: m[1].to_i }, number_in_season: m[2].to_i)
      else
        needle = squashed(query)
        return [] if needle.blank?
        scope = scope.where("#{squash_sql('episodes.title')} LIKE ?", "%#{needle}%")
      end

      scope.order("seasons.number, episodes.number_in_season").limit(LIMIT).map do |e|
        { label: "S#{e.season.number}E#{e.number_in_season} #{e.title}",
          sub: e.season.series&.name.to_s.presence || "Episode",
          path: episode_path(e) }
      end
    end
  end
end
