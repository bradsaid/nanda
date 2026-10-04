module Admin
  class EpisodesController < BaseController
    before_action :require_full_admin!, only: %i[new create destroy]
    before_action :set_episode, only: %i[show edit update destroy]

    def index
      # Traffic per episode over the last 30 days, keyed by episode id.
      # Cached so the /admin/episodes page doesn't rescan PageView on every hit.
      path_counts = Rails.cache.fetch("admin/episodes/traffic_counts/v1", expires_in: 5.minutes) do
        PageView.where(created_at: 30.days.ago..)
                .where("path ~ ?", '^/episodes/[0-9]+$')
                .group(:path).count
      end
      @traffic_by_episode_id = path_counts.each_with_object({}) do |(path, count), h|
        id = path.split("/").last.to_i
        h[id] = count if id.positive?
      end

      scope = Episode.includes(season: :series, location: {}, episode_traps: {})
                     .joins(season: :series)

      case params[:filter]
      when "missing_synopsis"
        scope = scope.where(synopsis: [nil, ""])
      when "has_synopsis"
        scope = scope.where.not(synopsis: [nil, ""])
      end

      @missing_count = Episode.where(synopsis: [nil, ""]).count
      @with_count    = Episode.where.not(synopsis: [nil, ""]).count
      @filter        = params[:filter].to_s.presence
      @sort          = params[:sort].to_s.presence

      case @sort
      when "traffic"
        # Sort by 30d traffic desc, then untrafficked episodes by natural order
        with_traffic = scope.where(id: @traffic_by_episode_id.keys).to_a
        without      = scope.where.not(id: @traffic_by_episode_id.keys).order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC").to_a
        @episodes = with_traffic.sort_by { |ep| -(@traffic_by_episode_id[ep.id] || 0) } + without
      else
        @episodes = scope.order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC").to_a
      end

      # "Next up": highest-traffic episode still missing a synopsis, to give
      # the writer an obvious starting point when they open the page.
      top_ids     = @traffic_by_episode_id.sort_by { |_, c| -c }.map(&:first).first(100)
      missing_set = Episode.where(id: top_ids, synopsis: [nil, ""]).ids.to_set
      top_id      = top_ids.find { |id| missing_set.include?(id) }
      @next_up    = Episode.includes(season: :series, location: {}).find_by(id: top_id) if top_id
    end

    def show
      redirect_to edit_admin_episode_path(@episode)
    end

    def new
      @episode = Episode.new
      @episode.appearances.build
    end

    def create
      @episode = Episode.new(episode_params)
      if @episode.save
        redirect_to edit_admin_episode_path(@episode), notice: "Episode created. Now add traps, shelters, and food sources."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      attrs = dedupe_appearances(dedupe_appearance_items(episode_params))
      if @episode.update(attrs)
        redirect_to admin_episodes_path, notice: "Episode updated."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      # appearances has a unique index on (survivor_id, episode_id). The dedupe
      # above should make this unreachable, but a 500 is never the right
      # answer to a form submission — say what happened and keep their edits.
      @episode.assign_attributes(attrs.except(:appearances_attributes))
      flash.now[:alert] = "A survivor was listed more than once on this episode. Each survivor can appear only once — remove the duplicate row and save again."
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @episode.destroy
      redirect_to admin_episodes_path, notice: "Episode deleted."
    end

    private

    def set_episode
      @episode = Episode.includes(
        appearances: [:survivor, { appearance_items: :item }],
        food_sources: [],
        episode_traps: [],
        episode_shelters: [],
        medical_calls: [],
        bushcraft_items: []
      ).find(params[:id])
    end

    # Drop any new appearance_items rows that would collide with an existing
    # (appearance_id, item_id, source) — the DB has a unique index on that
    # triple. This guards against the Quick Add Given Item button being used
    # to fan out an item to a survivor who already has it.
    # The participant copy button appended a row for every survivor on the
    # previous episode without checking who was already on this one. Saving
    # then hit the unique index on (survivor_id, episode_id) and 500'd. Drop
    # any NEW row whose survivor is already present — on an existing row, or
    # earlier in the submission — so the first mention wins.
    def dedupe_appearances(attrs)
      apps = attrs[:appearances_attributes]
      return attrs unless apps.is_a?(ActionController::Parameters) || apps.is_a?(Hash)

      existing = @episode ? @episode.appearances.pluck(:survivor_id, :id).to_h { |sid, id| [sid.to_s, id.to_s] } : {}
      seen = {}
      apps.to_h.each do |key, row|
        next if row[:_destroy].to_s == "1"
        sid = row[:survivor_id].to_s
        next if sid.empty?
        if row[:id].present?
          seen[sid] = key
        elsif seen.key?(sid) || existing.key?(sid)
          apps.delete(key)
        else
          seen[sid] = key
        end
      end
      attrs
    end

    def dedupe_appearance_items(attrs)
      apps = attrs[:appearances_attributes]
      return attrs unless apps.is_a?(ActionController::Parameters) || apps.is_a?(Hash)

      apps.each do |_ap_key, ap|
        items = ap[:appearance_items_attributes]
        next unless items.is_a?(ActionController::Parameters) || items.is_a?(Hash)

        seen = {}
        items.to_h.each do |item_key, row|
          next if row[:_destroy].to_s == "1"
          item_id = row[:item_id].to_s
          source  = row[:source].to_s
          subtype = row[:subtype].to_s.strip
          next if item_id.empty?
          key = [item_id, source, subtype]
          if row[:id].present?
            seen[key] = item_key
          elsif seen.key?(key)
            items.delete(item_key)
          else
            seen[key] = item_key
          end
        end
      end

      attrs
    end

    def episode_params
      params.require(:episode).permit(
        :season_id, :number_in_season, :title, :air_date,
        :scheduled_days, :participant_arrangement, :type_modifiers,
        :location_id, :notes, :synopsis, :no_traps,
        appearances_attributes: [
          :id, :survivor_id, :role, :starting_psr, :ending_psr,
          :days_lasted, :result, :weight_loss, :partner_replacement, :_destroy,
          appearance_items_attributes: [
            :id, :item_id, :subtype, :source, :quantity, :_destroy
          ]
        ],
        food_sources_attributes: [
          :id, :name, :category, :method, :quantity, :episode_trap_id, :tools_used, :notes, :_destroy, survivor_ids: []
        ],
        episode_traps_attributes: [
          :id, :trap_type, :result, :notes, :_destroy, builder_ids: []
        ],
        episode_shelters_attributes: [
          :id, :shelter_type, :materials, :notes, :_destroy, builder_ids: []
        ],
        medical_calls_attributes: [
          :id, :survivor_id, :reason, :led_to_tapout, :notes, :_destroy
        ],
        bushcraft_items_attributes: [
          :id, :item_type, :materials, :notes, :_destroy, builder_ids: []
        ]
      )
    end
  end
end
