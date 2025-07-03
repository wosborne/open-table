# app/services/shopify_service.rb
class Shopify
  def initialize(shop_domain:, access_token:)
    @shop_domain = shop_domain
    @access_token = access_token
    @session = setup_session
  end

  def get_products
    @session.get(path: "products").body["products"]
  end

  # Publish (create or update) a product on the user's store
  # product_params should be a hash matching ShopifyAPI::Product attributes
  def publish_product(product_params)
    if product_params[:id]
      # ✅ Update existing product
      response = @session.put(
        path: "products/#{product_params[:id]}",
        body: { product: product_params.except(:id) }
      )
      if response.code == 200
        response.body["product"]
      else
        raise StandardError, "Error updating product: #{response.body}"
      end
    else
      # ✅ Create new product
      response = @session.post(
        path: "products",
        body: { product: product_params }
      )
      if response.code == 201
        response.body["product"]
      else
        raise StandardError, "Error creating product: #{response.body}"
      end
    end
  end

  # Remove a product from the user's store by product ID
  def remove_product(product_id)
    product = ShopifyAPI::Product.find(product_id)
    product.destroy
  end

  private

  def setup_session
    ShopifyAPI::Context.setup(
      api_key: Rails.application.credentials.shopify[:client_id],
      api_secret_key: Rails.application.credentials.shopify[:client_secret],
      host_name: @shop_domain,
      api_version: "2024-04",
      is_embedded: false,
      is_private: true
    )

    ShopifyAPI::Clients::Rest::Admin.new(
      session: ShopifyAPI::Auth::Session.new(
        shop: @shop_domain,
        access_token: @access_token
      )
    )
  end
end
