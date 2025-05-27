Rails.application.configure do
  # Enable session store for the application
  config.session_store :cookie_store, key: "phone_fliprr", domain: :all
end
