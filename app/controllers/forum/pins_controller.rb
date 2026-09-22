module Forum
  # Moderators pin a topic to the top of the list. Pinned topics lead every
  # sort order, so this is the one control that outranks the reader's choice.
  class PinsController < BaseController
    before_action :set_topic
    before_action :require_moderator

    def create  = set_pinned(true)
    def destroy = set_pinned(false)

    private

    def set_pinned(value)
      @topic.update!(pinned: value)
      redirect_to forum_topic_path(@topic),
                  notice: value ? "Topic pinned to the top." : "Topic unpinned."
    end

    def set_topic
      @topic = Forum::Topic.active.friendly.find(params[:topic_slug])
    end

    def require_moderator
      return if admin_signed_in?
      redirect_to forum_topic_path(@topic), alert: "Only moderators can pin topics."
    end
  end
end
