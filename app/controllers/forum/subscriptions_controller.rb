module Forum
  class SubscriptionsController < BaseController
    before_action :set_topic

    def create
      current_user.forum_subscriptions.find_or_create_by!(forum_topic: @topic)
      redirect_to forum_topic_path(@topic), notice: "Subscribed. You'll be emailed on new replies."
    end

    def destroy
      current_user.forum_subscriptions.where(forum_topic: @topic).delete_all
      redirect_to forum_topic_path(@topic), notice: "Unsubscribed."
    end

    private

    def set_topic
      @topic = Forum::Topic.active.friendly.find(params[:topic_slug])
    end
  end
end
