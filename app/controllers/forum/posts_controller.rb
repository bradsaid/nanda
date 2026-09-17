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

      if (offender = first_disguised_upload(params.dig(:post, :images) || params.dig(:forum_post, :images)))
        @post.errors.add(:images, "\"#{offender}\" is not a real image file")
        return render_reply_error
      end

      if @post.save
        current_user.forum_subscriptions.find_or_create_by!(forum_topic: @topic)
        # Without the page, a reply sent from page 2 dropped the author back on
        # page 1 with their new post nowhere in sight.
        redirect_to forum_topic_path(@topic, page: page_for(@post), anchor: "post-#{@post.id}"),
                    notice: "Reply posted."
      else
        # A redirect cannot carry the draft, so the author lost everything they
        # had typed whenever an attachment was rejected. Re-render the topic
        # with the reply still in the box, as the new-topic composer does.
        render_reply_error
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

    # Re-render the topic page with the failed reply (and its errors) still in
    # the composer. Mirrors TopicsController#show so the page is complete.
    def render_reply_error
      flash.now[:alert] = @post.errors.full_messages.to_sentence
      @posts = @topic.posts
                     .active
                     .includes(:user, images_attachments: :blob)
                     .chronological
                     .page(params[:page]).per(Forum::Topic::POSTS_PER_PAGE)
      @new_post = @post
      render "forum/topics/show", status: :unprocessable_entity
    end

    def set_topic
      @topic = Forum::Topic.active.friendly.find(params[:topic_slug])
    end

    # Which page of the topic does this post fall on, counting only the posts
    # that are actually rendered (soft-deleted ones are skipped in the view, so
    # counting all rows would drift the page number).
    def page_for(post)
      position = post.forum_topic.posts.active.where("forum_posts.created_at <= ?", post.created_at).count
      [(position.to_f / Forum::Topic::POSTS_PER_PAGE).ceil, 1].max
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
