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

  resources :accounts, only: %w[new create edit update]

  get "/marketplace", to: "marketplace#index"

  post "/webhooks/shopify", to: "shopify_webhooks#receive"
  match "/webhooks/ebay/marketplace_account_deletion", to: "ebay_webhooks#marketplace_account_deletion", via: [:get, :post]


  scope "/:account_slug", as: :account do
    resources :external_accounts, only: %w[new create destroy show] do
      member do
        post :opt_into_business_policies
        post :create_fulfillment_policy
        post :create_custom_fulfillment_policy
        post :create_inventory_location
      end
    end

    resources :products do
      member do
        patch :regenerate_skus
      end
      resources :external_account_products
    end

    resources :inventory_units do
      get :variant_selector, on: :collection
      member do
        delete :delete_image_attachment
      end
      resources :external_account_inventory_units, only: [:create, :destroy]
    end

    resources :locations

    resources :orders, only: [ :index, :show, :edit ]

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

  get "/external_accounts/shopify_callback", to: "external_accounts#shopify_callback"
  get "/external_accounts/ebay_callback", to: "external_accounts#ebay_callback"
  match "/ebay/marketplace_notifications", to: "ebay_notifications#marketplace_notifications", via: [:get, :post]
end
