module Forum
  class TopicsController < BaseController
    before_action :set_category, only: [:new, :create]
    before_action :set_topic,    only: [:show, :edit, :update, :destroy]

    def show
      @posts = @topic.posts
                      .active
                      .includes(:user, images_attachments: :blob)
                      .chronological
                      .page(params[:page]).per(20)
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
      @new_post = Forum::Post.new(body: body_text)
      render :new, status: :unprocessable_entity
    end

    def edit
      require_ownership(@topic)
    end

    def update
      require_ownership(@topic)
      if @topic.update(topic_params.slice(:title))
        redirect_to forum_topic_path(@topic), notice: "Updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      require_ownership(@topic, allow_admin: true)
      @topic.update!(deleted_at: Time.current)
      redirect_to forum_category_path(@topic.forum_category), notice: "Topic removed."
    end

    private

    def set_category
      @category = Forum::Category.friendly.find(params[:category_slug])
    end

    def set_topic
      @topic = Forum::Topic.active.friendly.find(params[:slug])
    end

    def topic_params
      key = params[:forum_topic] ? :forum_topic : :topic
      params.require(key).permit(:title)
    end

    def require_ownership(topic, allow_admin: false)
      return if topic.user_id == current_user&.id
      return if allow_admin && admin_signed_in?
      redirect_to forum_topic_path(topic), alert: "Not your topic." and return
    end
  end
end
