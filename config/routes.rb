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

  resources :accounts, only: %w[new create edit update show]

  post "/webhooks/shopify", to: "shopify_webhooks#receive"
  match "/webhooks/ebay/marketplace_account_deletion", to: "ebay_webhooks#marketplace_account_deletion", via: [:get, :post]
  post "/webhooks/ebay/notifications", to: "ebay_webhooks#notifications", as: :ebay_webhooks


  scope "/:account_slug", as: :account do
    get "dashboard", to: "dashboard#index"
    post "ebay/opt_into_business_policies", to: "ebay#opt_into_business_policies"
    
    resources :external_accounts, only: %w[new create destroy show edit update] do
      member do
        get :fulfillment_policies
        get :payment_policies
        get :return_policies
        get :inventory_locations
      end
      
      resources :fulfillment_policies, only: [:new, :create, :edit, :update, :show, :destroy] do
        collection do
          get :shipping_services
        end
      end
      
      resources :return_policies, only: [:new, :create, :edit, :update, :show, :destroy]
      
      resources :payment_policies, only: [:new, :create, :edit, :update, :show, :destroy]
    end

    resources :products do
      member do
        patch :regenerate_skus
      end
      collection do
        get :ebay_category_aspects
      end
      resources :external_account_products
    end

    resources :inventory_units do
      get :variant_selector, on: :collection
      member do
        delete :delete_image_attachment
      end
      resources :external_account_inventory_units, only: [:show, :new, :create, :update, :destroy]
    end

    resources :variants do
      get :product_options, on: :collection
    end

    resources :locations

    resources :orders, only: [ :index, :show, :edit ]

    resources :ebay_notifications, only: [:index, :destroy] do
      delete :clear_all, on: :collection
    end

    # Custom tables routes disabled
    # resources :tables do
    #   resources :properties, only: %w[create update destroy] do
    #     get :type_fields, on: :member
    #     post :refresh_cells, on: :member
    #   end
    #
    #   resources :records, only: %w[create update destroy] do
    #     delete :delete_records, on: :collection
    #   end
    #
    #   resources :views, only: %w[create show update destroy] do
    #     resources :view_properties do
    #       patch :set_positions, on: :collection
    #       patch :set_visibility, on: :member
    #     end
    #
    #     get :filter_field, on: :member
    #     patch :set_record_attribute, on: :member
    #   end
    #
    #   get :property_options, on: :member
    #   patch :set_record_attribute, on: :member
    # end

    resources :shopify
  end

  get "/external_accounts/shopify_callback", to: "external_accounts#shopify_callback"
  get "/external_accounts/ebay_callback", to: "external_accounts#ebay_callback"
  match "/ebay/marketplace_notifications", to: "ebay_notifications#marketplace_notifications", via: [:get, :post]
end
