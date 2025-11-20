require Rails.root.join("app/models/shopify_webhook_handler.rb")

ShopifyAPI::Context.setup(
  api_key: Rails.application.credentials.shopify[:client_id],
  api_secret_key: Rails.application.credentials.shopify[:client_secret],
  host_name: "64fbd59ed37a.ngrok-free.app",
  scope: "read_products,write_products,read_inventory,write_inventory",
  is_embedded: false, # Set to true if you are building an embedded app
  is_private: false, # Set to true if you are building a private app
  api_version: "2025-04" # The version of the API you would like to use
)

ShopifyAPI::Webhooks::Registry.add_registration(
  topic: "orders/create",
  delivery_method: :http,
  handler: ShopifyWebhookHandler,
  path: "/webhooks/shopify"
)
