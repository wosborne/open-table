# app/services/shopify_service.rb
class ShopifyService < BaseExternalService
  def initialize(external_account:, shop_domain: nil, access_token: nil)
    super(external_account: external_account)
    @shop_domain = shop_domain || external_account.domain
    @access_token = access_token || external_account.api_token
    @session = setup_session
  end

  def get_products
    with_token_refresh do
      @session.get(path: "products").body["products"]
    end
  end

  # Publish (create or update) a product on the user's store
  # product_params should be a hash matching ShopifyAPI::Product attributes
  def publish_product(product_params)
    with_token_refresh do
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
  end

  # Remove a product from the user's store by product ID
  def remove_product(product_id)
    with_token_refresh do
      response = @session.delete(path: "products/#{product_id}")
      response.code == 200 || response.code == 204
    end
  end

  protected

  def token_expired?(error)
    error.is_a?(ShopifyAPI::Errors::HttpResponseError) && 
      error.message.include?("Invalid API key or access token")
  end

  def refresh_access_token
    return unless @external_account&.refresh_token

    response = HTTParty.post("https://#{@shop_domain}/admin/oauth/access_token", {
      body: {
        client_id: Rails.application.credentials.shopify[:client_id],
        client_secret: Rails.application.credentials.shopify[:client_secret],
        refresh_token: @external_account.refresh_token,
        grant_type: 'refresh_token'
      },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
    })

    if response.success?
      new_token = response.parsed_response['access_token']
      @external_account.update!(api_token: new_token)
      @access_token = new_token
      @session = setup_session
      true
    else
      false
    end
  end

  private

  def setup_session
    ShopifyAPI::Context.setup(
      api_key: Rails.application.credentials.shopify[:client_id],
      api_secret_key: Rails.application.credentials.shopify[:client_secret],
      host_name: @shop_domain,
      api_version: "2024-04",
      is_embedded: false,
      is_private: false
    )

    ShopifyAPI::Clients::Rest::Admin.new(
      session: ShopifyAPI::Auth::Session.new(
        shop: @shop_domain,
        access_token: @access_token
      )
    )
  end
end
