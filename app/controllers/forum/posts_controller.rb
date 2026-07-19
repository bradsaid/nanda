module Forum
  class PostsController < BaseController
    EDIT_WINDOW = 15.minutes

    before_action :set_topic, only: [:create]
    before_action :set_post,  only: [:edit, :update, :destroy]

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

    def edit
      require_editable(@post)
    end

    def update
      require_editable(@post)
      if @post.update(post_params.merge(edited_at: Time.current))
        redirect_to forum_topic_path(@post.forum_topic, anchor: "post-#{@post.id}"), notice: "Updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      require_editable(@post, allow_admin: true)
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

    def require_editable(post, allow_admin: false)
      return if admin_signed_in? && allow_admin
      unless post.user_id == current_user&.id
        redirect_to forum_topic_path(post.forum_topic), alert: "Not your post." and return
      end
      if post.created_at < EDIT_WINDOW.ago && !admin_signed_in?
        redirect_to forum_topic_path(post.forum_topic), alert: "Edit window expired." and return
      end
    end
  end
end
