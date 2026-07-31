Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords,
    param: :token,
    only: %i[new create edit update]
  resource :registration, only: %i[new create]

  get "dashboard", to: "dashboard#show", as: :dashboard

  resources :shared_resources,
    path: "resources" do
    member do
      patch :archive
      patch :restore
    end
  end

  root "marketing#show"

  get "up" => "rails/health#show", as: :rails_health_check
end
