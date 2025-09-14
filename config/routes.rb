# config/routes.rb
Rails.application.routes.draw do
  resource  :session,    only: %i[new create destroy]
  resources :passwords,  only: %i[new create edit update], param: :token

  namespace :admin do
    resource :dashboard, only: :show
    root to: "dashboard#show"
  end

  resources :survivors, only: [:index, :show] do
    get :datatable, on: :collection
  end

  resources :episodes,  only: [:index, :show]
  resources :items,     only: [:index, :show]
  resources :locations, only: [:index]

  # NEW:
  get "home", to: "home#index"
  root "home#index"
end
