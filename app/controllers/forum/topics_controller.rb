module Forum
  class TopicsController < BaseController
    before_action :set_category, only: [:new, :create]
    TOPICS_PER_PAGE = 30
    before_action :ensure_category_unlocked, only: [:new, :create]
    before_action :set_topic,    only: [:show, :edit, :update, :destroy]
    # Ownership guards must run as before_actions: a redirect_to inside a
    # before_action halts the filter chain, whereas calling them from inside
    # the action body only returned from the guard itself and let the write
    # go through.
    before_action :require_topic_owner,             only: [:edit, :update]
    before_action :require_topic_owner_or_moderator, only: [:destroy]

    # The whole forum in one list — there is no category browsing layer.
    def index
      @topics = Forum::Topic.active
                            .includes(:user, :last_post_user)
                            .in_order
                            .page(params[:page]).per(TOPICS_PER_PAGE)
      # posts_count counts soft-deleted posts, so count live ones instead.
      @active_post_counts = Forum::Post.active
                                       .where(forum_topic_id: @topics.map(&:id))
                                       .group(:forum_topic_id)
                                       .count
    end

    def show
      @posts = @topic.posts
                      .active
                      .includes(:user, images_attachments: :blob)
                      .chronological
                      .page(params[:page]).per(Forum::Topic::POSTS_PER_PAGE)
      @new_post = Forum::Post.new
      @topic.increment!(:views_count) unless request.headers["Turbo-Frame"].present?
    end

    def new
      @topic    = @category.topics.new
      @new_post = @topic.posts.new
    end

    def create
      body_text = (params.dig(:forum_topic, :body) || params.dig(:topic, :body)).to_s
      images    = Array(params.dig(:forum_topic, :images) || params.dig(:topic, :images)).reject(&:blank?)
      if (offender = first_disguised_upload(images))
        @topic    = @category.topics.new(title: params.dig(:forum_topic, :title))
        @new_post = Forum::Post.new(body: body_text)
        flash.now[:alert] = "\"#{offender}\" is not a real image file."
        return render :new, status: :unprocessable_entity
      end

      Forum::Topic.transaction do
        @topic = @category.topics.new(topic_params)
        @topic.user = current_user
        if @topic.save
          @new_post = @topic.posts.create!(user: current_user, body: body_text, images: images)
          current_user.forum_subscriptions.find_or_create_by!(forum_topic: @topic)
          redirect_to forum_topic_path(@topic), notice: "Topic posted."
        else
          @new_post = @topic.posts.new(body: body_text)
          flash.now[:alert] = "Please fix the errors below."
          render :new, status: :unprocessable_entity
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      @topic    ||= @category.topics.new
      @new_post   = Forum::Post.new(body: body_text)
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      if @topic.update(topic_params.slice(:title))
        redirect_to forum_topic_path(@topic), notice: "Updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @topic.update!(deleted_at: Time.current)
      redirect_to forum_path, notice: "Topic removed."
    end

    private

    # No category is chosen by the author any more; new topics land in the
    # default one so the existing schema still has a parent row to point at.
    def set_category
      @category = Forum::Category.default
      raise ActionController::RoutingError, "Not Found" if @category.nil?
    end

    # Admins set "Locked (no new topics)" per category; it had no effect
    # because nothing ever read the flag. Moderators can still post.
    def ensure_category_unlocked
      return unless @category.locked?
      return if admin_signed_in?
      redirect_to forum_path, alert: "The forum is closed to new topics."
    end

    def set_topic
      @topic = Forum::Topic.active.friendly.find(params[:slug])
    end

    # The new-topic form posts the title under forum_topic[] and the edit form
    # under topic[]. Pick whichever key actually carries the title so a form
    # that splits fields across both keys can't silently drop it.
    def topic_params
      key = params[:forum_topic].respond_to?(:key?) && params[:forum_topic].key?(:title) ? :forum_topic : :topic
      params.require(key).permit(:title)
    end

    def require_topic_owner              = require_ownership(@topic)
    def require_topic_owner_or_moderator = require_ownership(@topic, allow_admin: true)

    def require_ownership(topic, allow_admin: false)
      return if topic.user_id == current_user&.id
      return if allow_admin && admin_signed_in?
      redirect_to forum_topic_path(topic), alert: "Not your topic."
    end
  end
end
