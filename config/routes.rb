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
  root "root#index"

  resources :accounts, only: %w[new create]

  get "/marketplace", to: "marketplace#index"

  scope "/:account_slug", as: :account do
    resources :products do
      resources :external_account_products
    end

    resources :tables do
      resources :properties, only: %w[create update destroy] do
        get :type_fields, on: :member
        post :refresh_cells, on: :member
      end

      resources :records, only: %w[create update destroy] do
        delete :delete_records, on: :collection
      end

      resources :views, only: %w[create show update destroy] do
        resources :view_properties do
          patch :set_positions, on: :collection
          patch :set_visibility, on: :member
        end

        get :filter_field, on: :member
        patch :set_record_attribute, on: :member
      end

      get :property_options, on: :member
      patch :set_record_attribute, on: :member
    end

    resources :shopify
  end

  get "/shopify_auth", to: "shopify_auth#oauth_redirect"
  get "/shopify_auth/callback", to: "shopify_auth#callback"
end
