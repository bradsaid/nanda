module Admin
  class EpisodesController < BaseController
    before_action :require_full_admin!, only: %i[new create destroy]
    before_action :set_episode, only: %i[show edit update destroy]

    def index
      @episodes = Episode.includes(season: :series).includes(:location, :episode_traps)
                         .joins(season: :series)
                         .order("series.name ASC, seasons.number ASC, episodes.number_in_season ASC")
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
      attrs = dedupe_appearance_items(episode_params)
      if @episode.update(attrs)
        redirect_to admin_episodes_path, notice: "Episode updated."
      else
        render :edit, status: :unprocessable_entity
      end
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
