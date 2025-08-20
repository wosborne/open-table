class EbayService < BaseExternalService
  def initialize(external_account:)
    super(external_account: external_account)
    @client_id = Rails.application.credentials.dig(:ebay, :client_id)
    @client_secret = Rails.application.credentials.dig(:ebay, :client_secret)
    @dev_id = Rails.application.credentials.dig(:ebay, :dev_id)
    @access_token = external_account.api_token
    @sandbox = Rails.env.development? || Rails.env.test?
    @ebay_client = create_ebay_client
  end

  def get_products
    with_token_refresh do
      # Use eBay Browse API to get products
      # For now, return empty array as this would require implementing
      # the specific eBay API calls for inventory management
      []
    end
  end

  def publish_product(product_params)
    with_token_refresh do
      # Use eBay Trading API or Sell API to create listings
      # For now, return a mock response
      ebay_item = build_ebay_item(product_params)
      
      {
        "ItemID" => "123456789",
        "SKU" => product_params[:sku],
        "Title" => product_params[:title]
      }
    end
  end

  def remove_product(product_id)
    with_token_refresh do
      # Use eBay Trading API EndItem to remove listings
      true
    end
  end

  protected

  def token_expired?(error)
    # eBay API error detection for expired tokens
    error.is_a?(StandardError) && 
      (error.message.include?("token") || 
       error.message.include?("unauthorized") ||
       error.message.include?("expired"))
  end

  def refresh_access_token
    return false unless external_account.refresh_token

    begin
      # Manual token refresh for eBay OAuth
      token_url = @sandbox ? "https://api.sandbox.ebay.com/identity/v1/oauth2/token" : "https://api.ebay.com/identity/v1/oauth2/token"
      
      response = RestClient.post(
        token_url,
        {
          grant_type: "refresh_token",
          refresh_token: external_account.refresh_token
        },
        {
          "Authorization" => "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}",
          "Content-Type" => "application/x-www-form-urlencoded"
        }
      )
      
      token_response = JSON.parse(response.body)
      
      if token_response && token_response['access_token']
        # Update the external account with new token
        external_account.update!(
          api_token: token_response['access_token'],
          refresh_token: token_response['refresh_token'] || external_account.refresh_token
        )
        @access_token = token_response['access_token']
        @ebay_client = create_ebay_client
        true
      else
        false
      end
    rescue => e
      Rails.logger.error "Failed to refresh eBay token: #{e.message}"
      false
    end
  end

  private

  def create_ebay_client
    # Create eBay API client using ebay-ruby gem
    Ebay.configure do |config|
      config.app_id = @client_id
      config.dev_id = @dev_id
      config.cert_id = @client_secret
      config.sandbox = @sandbox
    end

    # Return a client instance (this may vary based on ebay-ruby gem version)
    Ebay
  end

  def build_ebay_item(product_params)
    # Map Rails product structure to eBay item structure
    # This is a basic mapping - you'll need to customize based on your needs
    {
      Title: product_params[:title],
      Description: product_params[:description] || product_params[:title],
      PrimaryCategory: { CategoryID: "166" }, # Cell Phones & Smartphones
      StartPrice: product_params[:price] || "0.99",
      ListingDuration: "Days_7",
      ListingType: "FixedPriceItem",
      Country: "US",
      Currency: "USD",
      PaymentMethods: ["PayPal"],
      PayPalEmailAddress: "your-paypal@email.com", # You'll need to make this configurable
      ShippingDetails: {
        ShippingType: "Flat",
        ShippingServiceOptions: [{
          ShippingServicePriority: 1,
          ShippingService: "USPSMedia",
          ShippingServiceCost: "2.50"
        }]
      }
    }
  end
end