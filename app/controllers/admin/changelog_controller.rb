module Admin
  class ChangelogController < BaseController
    before_action :require_full_admin!

    def index
      @versions = PaperTrail::Version
                    .order(created_at: :desc)
                    .limit(300)
    end

    def revert
      version = PaperTrail::Version.find(params[:id])

      if version.event != "update"
        redirect_to admin_changelog_index_path,
                    alert: "Only update events can be reverted from here."
        return
      end

      reified = version.reify(has_many: false)
      if reified.nil?
        redirect_to admin_changelog_index_path,
                    alert: "Nothing to revert — could not rebuild previous state."
        return
      end

      if reified.save
        redirect_to admin_changelog_index_path,
                    notice: "Reverted #{version.item_type} ##{version.item_id} to its prior values."
      else
        redirect_to admin_changelog_index_path,
                    alert: "Revert failed: #{reified.errors.full_messages.to_sentence}"
      end
    end
  end
end
