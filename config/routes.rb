Rails.application.routes.draw do
  resource  :session,    only: %i[new create destroy]
  resources :passwords,  only: %i[new create edit update], param: :token

  namespace :admin do
    resource :dashboard, only: :show
    root to: "dashboard#show"
  end

  root "admin/dashboard#show"  # temp: admin as homepage
end
