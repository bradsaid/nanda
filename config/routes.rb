# config/routes.rb
Rails.application.routes.draw do


  resource  :session,    only: %i[new create destroy]
  resources :passwords,  only: %i[new create edit update], param: :token

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
  end

  resources :survivors, only: [:index, :show]
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
