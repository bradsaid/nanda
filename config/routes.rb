# config/routes.rb
Rails.application.routes.draw do

  # Silence log noise from probes we don't need to respond to:
  # - /assets/json_ld/inject: some visitor's browser/extension keeps
  #   requesting this asset that has never existed in our codebase.
  # - /.well-known/traffic-advice: Chromium's prefetch-proxy advice probe.
  # Both are served as 204 No Content instead of routing-error 404s.
  match "/assets/json_ld/inject",      to: ->(_env) { [204, {}, []] }, via: :all
  match "/.well-known/traffic-advice", to: ->(_env) { [204, {}, []] }, via: :all

  # Built from the database on each (cached) request; see SitemapUrls. There must be no
  # public/sitemap*.xml, which the static file server would serve ahead of this.
  get "/sitemap.xml",  to: "sitemaps#show", defaults: { format: "xml" }
  get "/sitemap1.xml", to: redirect("/sitemap.xml", status: 301) # the old generated child file

  # Counted redirect for affiliate buy buttons. The destination always comes from
  # ShopCatalog (looked up by anchor), never from the request.
  get "/go/:slug", to: "affiliate_redirects#show", as: :go, constraints: { slug: /[a-z0-9-]+/ }

  resource  :session,    only: %i[new create destroy]
  resources :passwords,  only: %i[new create edit update], param: :token

  # Forum-account signup + email verification. Auth surfaces are always
  # available (even with FORUM_ENABLED=false) so we can build and test them
  # in isolation before flipping the flag on.
  get  "/signup", to: "registrations#new",    as: :signup
  post "/signup", to: "registrations#create"

  # The emailed link only SHOWS a confirmation button (GET); the change itself
  # is a POST. Mail scanners and link-preview bots fetch every URL in a message,
  # and a GET that changed state let them confirm on the member's behalf.
  # Must precede POST /email/verify/:token, which would otherwise capture "resend".
  post "/email/verify/resend",  to: "email_verifications#resend", as: :resend_email_verification
  get  "/email/change/:token",   to: "email_changes#show",         as: :email_change
  post "/email/change/:token",   to: "email_changes#update"
  get  "/email/verify/:token",  to: "email_verifications#show",   as: :email_verification
  post "/email/verify/:token",  to: "email_verifications#update"

  # Forum routes. Every controller under Forum:: refuses to serve if
  # ENV["FORUM_ENABLED"] != "true" (see Forum::BaseController), so it's safe
  # to define them here even before the public launch.
  # One forum, no categories: /forum is the topic list itself. Categories still
  # exist in the schema (topics need one) but are not a browsing surface, so the
  # old category URLs redirect rather than 404 for anyone holding a link.
  get  "/forum", to: "forum/topics#index", as: :forum
  # The Community Guidelines are an ordinary public page, deliberately NOT under
  # Forum::BaseController: they must stay readable (and crawlable) logged out and
  # whether or not FORUM_ENABLED is set, so the signup page can always link to them.
  # Declared before the /forum scope so no forum route can capture the path.
  get "/forum/guidelines", to: "static_pages#guidelines", as: :forum_guidelines
  get "/guidelines",       to: redirect("/forum/guidelines", status: 301)
  scope "/forum", module: :forum, as: :forum do
    get "/mentions",         to: "mentions#index", as: :mentions
    get "/categories",       to: redirect("/forum")
    get "/categories/:slug", to: redirect("/forum")
    resources :topics, param: :slug, only: [:new, :create, :show, :edit, :update, :destroy] do
      resources :posts, only: [:create]
      resource  :subscription, only: [:create, :destroy]
      resource  :pin,          only: [:create, :destroy]
    end
    resources :posts, only: [:edit, :update, :destroy] do
      resource :report, only: [:new, :create]
    end
    get   "/users",                to: "profiles#index",  as: :profiles
    get   "/users/:username",      to: "profiles#show",   as: :profile,      constraints: { username: /[A-Za-z0-9_]+/ }
    get   "/users/:username/edit", to: "profiles#edit",   as: :edit_profile, constraints: { username: /[A-Za-z0-9_]+/ }
    patch "/users/:username",      to: "profiles#update",                    constraints: { username: /[A-Za-z0-9_]+/ }
    post  "/users/:username/email", to: "profiles#request_email_change", as: :request_email_change, constraints: { username: /[A-Za-z0-9_]+/ }
    delete "/users/:username/email", to: "profiles#cancel_email_change", as: :cancel_email_change, constraints: { username: /[A-Za-z0-9_]+/ }
  end

  namespace :admin do
    root to: "dashboard#show"
    get "dashboard", to: "dashboard#show"
    resource  :password, only: %i[edit update]
    resources :survivors
    get "synopsis_queue", to: "synopsis_queue#index"
    resources :affiliate_clicks, only: [:index]
    get "shop", to: redirect("/shop", status: 301) # moved to the public shop
    resources :seasons do
      member do
        get :latest_episode_participants
      end
    end
    resources :episodes
    resources :changelog, only: [:index] do
      member do
        post :revert
      end
    end

    # Forum moderation surfaces (namespaced under admin).
    namespace :forum do
      resources :categories, only: [:index, :new, :create, :edit, :update, :destroy]
      resources :reports,    only: [:index, :update]
      resources :users,      only: [:index, :update, :destroy] do
        member { post :password_reset }
      end
    end
  end

  resources :survivors, only: [:index, :show] do
    member do
      post :submit, to: "survivor_submissions#create", as: :submit
      # Bots (Bing especially) follow the form's action URL as GET and 404.
      # Redirect back to the survivor page so it's a clean 301.
      get :submit, to: redirect { |params, _req| "/survivors/#{params[:id]}" }, status: 301
    end
  end
  resources :episodes, only: [:index, :show] do
    collection do
      get "by_country/:country", to: "episodes#by_country", as: :by_country
    end
  end
  resources :items, only: [:index, :show] do
    collection do
      get "types/:item_type", to: "items#type", as: :type
    end
  end
  # The constraint lets a name contain a dot; otherwise Rails reads everything
  # after it as a format and the lookup gets a truncated name.
  resources :food_sources, only: [:index, :show], param: :name, constraints: { name: /[^\/]+/ }
  resources :shelters, only: [:index, :show], param: :shelter_type, constraints: { shelter_type: /[^\/]+/ }
  resources :locations, only: [:index]
  resources :seasons,   only: [:index, :show]
  resources :series,    only: [:index, :show]
  get "shop", to: "shop#index"
  get "shop/guides", to: "shop_guides#index", as: :shop_guides
  get "shop/guides/:slug", to: "shop_guides#show", as: :shop_guide

  post "page_view_ping", to: "page_view_pings#create"

  get 'podcasts', to: 'static_pages#podcasts'
  get "home", to: "home#index"
  root "home#index"

 

  get "/about", to: "static_pages#about", as: :about
  get "/privacy_policy", to: "static_pages#privacy_policy", as: :privacy_policy
  get "/terms_of_service", to: "static_pages#terms_of_service", as: :terms_of_service
  get  "/contact", to: "static_pages#contact", as: :contact    # page
  post "/contact", to: "contact_messages#create", as: :contact_submit

  # Silence noisy browser/crawler default-icon probes. Our real icons are
  # linked from the <head>, but many clients still blindly GET these paths.
  get "/favicon.ico",                    to: redirect("/favicon.png", status: 301)
  get "/apple-touch-icon.png",           to: redirect("/favicon.png", status: 301)
  get "/apple-touch-icon-precomposed.png", to: redirect("/favicon.png", status: 301)
end
