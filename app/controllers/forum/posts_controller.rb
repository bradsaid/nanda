module Forum
  class PostsController < BaseController
    EDIT_WINDOW = 15.minutes

    before_action :set_topic, only: [:create]
    before_action :set_post,  only: [:edit, :update, :destroy]
    # Must be a before_action so the redirect halts the chain — calling this
    # from inside the action only returned from the guard and let the write
    # land before blowing up with a DoubleRenderError.
    before_action :require_editable, only: [:edit, :update, :destroy]

    def create
      if @topic.locked?
        redirect_to forum_topic_path(@topic), alert: "This topic is locked." and return
      end

      @post = @topic.posts.new(post_params)
      @post.user = current_user

      if @post.save
        current_user.forum_subscriptions.find_or_create_by!(forum_topic: @topic)
        redirect_to forum_topic_path(@topic, anchor: "post-#{@post.id}"), notice: "Reply posted."
      else
        redirect_to forum_topic_path(@topic), alert: @post.errors.full_messages.to_sentence
      end
    end

    def edit; end

    def update
      if @post.update(post_params.merge(edited_at: Time.current))
        redirect_to forum_topic_path(@post.forum_topic, anchor: "post-#{@post.id}"), notice: "Updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @post.update!(deleted_at: Time.current)
      redirect_to forum_topic_path(@post.forum_topic), notice: "Post removed."
    end

    private

    def set_topic
      @topic = Forum::Topic.active.friendly.find(params[:topic_slug])
    end

    def set_post
      @post = Forum::Post.active.find(params[:id])
    end

    def post_params
      key = params[:forum_post] ? :forum_post : :post
      params.require(key).permit(:body, images: [])
    end

    # Mirrors ForumHelper#can_edit_post?, which is what decides whether the
    # Edit link is rendered: moderators may always act, authors only inside
    # the edit window. These used to disagree, so the Edit link shown to a
    # moderator always bounced with "Not your post."
    def require_editable
      return if admin_signed_in?
      unless @post.user_id == current_user&.id
        redirect_to forum_topic_path(@post.forum_topic), alert: "Not your post."
        return
      end
      if @post.created_at < EDIT_WINDOW.ago
        redirect_to forum_topic_path(@post.forum_topic), alert: "Edit window expired."
      end
    end
  end
end
