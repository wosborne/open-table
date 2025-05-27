Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "tables#index"

  resources :accounts, only: %w[new create]

  scope "/:account_slug", as: :account do
    resources :tables do
      resources :properties, only: %w[create update] do
        get :type_fields, on: :member
        post :refresh_cells, on: :member
      end

      resources :items, only: %w[create update destroy] do
        patch :set_property, on: :member
      end

      get :property_options, on: :member
    end
  end
end
