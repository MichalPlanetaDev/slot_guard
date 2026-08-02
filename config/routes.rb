Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords,
    param: :token,
    only: %i[new create edit update]
  resource :registration, only: %i[new create]

  get "dashboard", to: "dashboard#show", as: :dashboard

  resource :current_workspace,
    only: :update

  resource :workspace_settings,
    path: "workspace/settings",
    only: %i[edit update]

  get "workspace/team",
    to: "workspace_team#show",
    as: :workspace_team

  get "workspace/activity",
    to: "audit_events#index",
    as: :workspace_activity

  resources :blackout_periods,
    path: "workspace/blackouts",
    only: %i[index create destroy]

  resources :workspace_invitations,
    path: "workspace/invitations",
    only: %i[create destroy]

  resources :workspace_memberships,
    path: "workspace/memberships",
    only: %i[update destroy]

  get "join/:token",
    to: "workspace_invitation_acceptances#show",
    as: :workspace_invitation_acceptance

  patch "join/:token",
    to: "workspace_invitation_acceptances#update"

  resources :shared_resources,
    path: "resources" do
    member do
      patch :archive
      patch :restore
    end

    resources :availability_windows,
      only: %i[create destroy]
  end

  get "reservations/series/new",
    to: "reservation_series#new",
    as: :new_reservation_series

  post "reservations/series",
    to: "reservation_series#create",
    as: :reservation_series_collection

  get "reservations/series/:id",
    to: "reservation_series#show",
    as: :reservation_series

  patch "reservations/:reservation_id/series/cancel",
    to: "reservation_series_cancellations#create",
    as: :cancel_reservation_series

  resources :reservations,
    only: %i[index new create show] do
    member do
      patch :cancel
    end
  end

  root "marketing#show"

  get "up" => "rails/health#show", as: :rails_health_check
end
