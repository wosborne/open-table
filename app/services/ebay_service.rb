class EbayService < BaseExternalService
  def initialize(external_account:)
    super(external_account: external_account)
    @client_id = Rails.application.credentials.dig(:ebay, :client_id)
    @client_secret = Rails.application.credentials.dig(:ebay, :client_secret)
    @dev_id = Rails.application.credentials.dig(:ebay, :dev_id)
    @access_token = external_account.api_token
    @token_url = Rails.application.credentials.dig(:ebay, :token_url)
    @api_base_url = Rails.application.credentials.dig(:ebay, :api_base_url)
    @sandbox = Rails.application.credentials.dig(:ebay, :sandbox)
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
      # Create inventory item using eBay Sell API
      inventory_item_data = build_inventory_item(product_params)
      
      response = RestClient.put(
        "#{@api_base_url}/sell/inventory/v1/inventory_item/#{product_params[:sku]}",
        inventory_item_data.to_json,
        {
          "Authorization" => "Bearer #{@access_token}",
          "Content-Type" => "application/json",
          "Content-Language" => "en-GB",
          "Accept" => "application/json"
        }
      )
      
      if response.code == 204
        # Success - eBay returns 204 No Content for successful inventory item creation
        {
          "success" => true,
          "sku" => product_params[:sku],
          "title" => product_params[:title]
        }
      else
        JSON.parse(response.body)
      end
    end
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error "eBay API error: #{e.response.body}"
    {
      "success" => false,
      "error" => JSON.parse(e.response.body)
    }
  end

  def remove_product(sku)
    with_token_refresh do
      # Delete inventory item using eBay Sell API
      response = RestClient.delete(
        "#{@api_base_url}/sell/inventory/v1/inventory_item/#{sku}",
        {
          "Authorization" => "Bearer #{@access_token}",
          "Content-Language" => "en-GB",
          "Accept" => "application/json"
        }
      )
      
      if response.code == 204
        # Success - eBay returns 204 No Content for successful deletion
        {
          "success" => true,
          "sku" => sku
        }
      else
        JSON.parse(response.body)
      end
    end
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error "eBay API delete error: #{e.response.body}"
    {
      "success" => false,
      "error" => JSON.parse(e.response.body)
    }
  end

  def create_inventory_location(location_key, location)
    return { "success" => true } unless location
    
    with_token_refresh do
      Rails.logger.info "Creating eBay inventory location: #{location_key}"
      
      location_data = build_location_data(location)
      Rails.logger.info "Location data: #{location_data.to_json}"
      
      response = RestClient.post(
        "#{@api_base_url}/sell/inventory/v1/location/#{location_key}",
        location_data.to_json,
        {
          "Authorization" => "Bearer #{@access_token}",
          "Content-Type" => "application/json",
          "Content-Language" => "en-GB",
          "Accept" => "application/json"
        }
      )
      
      Rails.logger.info "Create location response: #{response.code} - #{response.body}"
      
      if [200, 201, 204].include?(response.code)
        {
          "success" => true,
          "location_key" => location_key
        }
      else
        JSON.parse(response.body)
      end
    end
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error "eBay location creation error: #{e.response.body}"
    error_response = JSON.parse(e.response.body) rescue {}
    
    # If location already exists, that's fine
    if error_response.dig("errors", 0, "errorId") == 25700 # Location already exists
      {
        "success" => true,
        "location_key" => location_key,
        "message" => "Location already exists"
      }
    else
      {
        "success" => false,
        "error" => error_response
      }
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
      
      response = RestClient.post(
        @token_url,
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
    end

    # Return a client instance (this may vary based on ebay-ruby gem version)
    Ebay
  end

  def build_inventory_item(product_params)
    {
      product: {
        title: product_params[:title],
        description: product_params[:description] || product_params[:title]
      },
      condition: "USED_EXCELLENT",
      availability: {
        shipToLocationAvailability: {
          quantity: 1
        }
      }
    }
  end

  def build_location_data(location)
    country_code = "GB"  # Default to GB
    
    # Map common country names to ISO codes
    country_mapping = {
      "United Kingdom" => "GB",
      "UK" => "GB", 
      "Great Britain" => "GB",
      "England" => "GB",
      "Scotland" => "GB",
      "Wales" => "GB",
      "Northern Ireland" => "GB"
    }
    
    country_code = country_mapping[location.country] || location.country
    
    # Build address, excluding empty fields
    address = {
      addressLine1: location.address_line_1,
      city: location.city,
      postalCode: location.postcode,
      country: country_code
    }
    
    # Only add addressLine2 if it's present
    address[:addressLine2] = location.address_line_2 if location.address_line_2.present?
    
    # Only add stateOrProvince if it's present (required for US, optional for others)
    address[:stateOrProvince] = location.state if location.state.present?
    
    {
      name: location.name,
      location: {
        address: address
      },
      locationTypes: ["WAREHOUSE"],
      merchantLocationStatus: "ENABLED"
    }
  end
end