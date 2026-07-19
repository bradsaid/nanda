# config/routes.rb
Rails.application.routes.draw do

  # Silence log noise from probes we don't need to respond to:
  # - /assets/json_ld/inject: some visitor's browser/extension keeps
  #   requesting this asset that has never existed in our codebase.
  # - /.well-known/traffic-advice: Chromium's prefetch-proxy advice probe.
  # Both are served as 204 No Content instead of routing-error 404s.
  match "/assets/json_ld/inject",      to: ->(_env) { [204, {}, []] }, via: :all
  match "/.well-known/traffic-advice", to: ->(_env) { [204, {}, []] }, via: :all

  resource  :session,    only: %i[new create destroy]
  resources :passwords,  only: %i[new create edit update], param: :token

  # Forum-account signup + email verification. Auth surfaces are always
  # available (even with FORUM_ENABLED=false) so we can build and test them
  # in isolation before flipping the flag on.
  get  "/signup", to: "registrations#new",    as: :signup
  post "/signup", to: "registrations#create"

  get  "/email/verify/:token",  to: "email_verifications#show",   as: :email_verification
  post "/email/verify/resend",  to: "email_verifications#resend", as: :resend_email_verification

  # Forum routes. Every controller under Forum:: refuses to serve if
  # ENV["FORUM_ENABLED"] != "true" (see Forum::BaseController), so it's safe
  # to define them here even before the public launch.
  get  "/forum", to: "forum/categories#index", as: :forum
  scope "/forum", module: :forum, as: :forum do
    resources :categories, param: :slug, only: [:show] do
      resources :topics, param: :slug, only: [:new, :create]
    end
    resources :topics, param: :slug, only: [:show, :edit, :update, :destroy] do
      resources :posts, only: [:create]
      resource  :subscription, only: [:create, :destroy]
    end
    resources :posts, only: [:edit, :update, :destroy] do
      resource :report, only: [:new, :create]
    end
  end

  namespace :admin do
    root to: "dashboard#show"
    get "dashboard", to: "dashboard#show"
    resource  :password, only: %i[edit update]
    resources :survivors
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
      resources :posts,      only: [:destroy]
      resources :topics,     only: [:update, :destroy]
      resources :users,      only: [:update]
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
  resources :food_sources, only: [:index, :show], param: :name
  resources :shelters, only: [:index, :show], param: :shelter_type
  resources :locations, only: [:index]
  resources :seasons,   only: [:index, :show]
  resources :series,    only: [:index, :show]

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
