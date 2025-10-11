# config/routes.rb
Rails.application.routes.draw do


  resource  :session,    only: %i[new create destroy]
  resources :passwords,  only: %i[new create edit update], param: :token

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
  resources :locations, only: [:index]
  resources :seasons,   only: [:index, :show]
  resources :series,    only: [:index, :show]

  get 'podcasts', to: 'static_pages#podcasts'
  get "home", to: "home#index"
  root "home#index"

  post "contact", to: "static_pages#contact"

  get "/about", to: "static_pages#about", as: :about

  
end
