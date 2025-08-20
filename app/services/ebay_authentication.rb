require "securerandom"

class EbayAuthentication
  def initialize(params: nil)
    @params = params
    @client_id = Rails.application.credentials.dig(:ebay, :client_id)
    @client_secret = Rails.application.credentials.dig(:ebay, :client_secret)
    @redirect_uri = Rails.application.credentials.dig(:ebay, :redirect_url)
    @sandbox = Rails.env.development? || Rails.env.test?
  end

  def authentication_path(user)
    # Generate state for CSRF protection
    state = generate_state(user)
    
    # Build eBay OAuth authorization URL manually
    base_url = @sandbox ? "https://auth.sandbox.ebay.com/oauth2/authorize" : "https://auth.ebay.com/oauth2/authorize"
    
    "#{base_url}?" + {
      client_id: @client_id,
      response_type: 'code',
      redirect_uri: @redirect_uri,
      scope: scopes,
      state: state
    }.to_query
  end

  def decode_state(state)
    secret = Rails.application.credentials.secret_key_base
    decoded_token = JWT.decode(state, secret, true, { algorithm: "HS256" })
    decoded_token.first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  def create_external_account_for(user)
    # Exchange authorization code for access token
    token_response = JSON.parse(request_access_token.body)
    access_token = token_response["access_token"]
    refresh_token = token_response["refresh_token"]

    # Remove existing eBay account for this user
    user.accounts.first.external_accounts.find_by(service_name: "ebay")&.destroy
    
    user.accounts.first.external_accounts.create(
      service_name: "ebay",
      api_token: access_token,
      refresh_token: refresh_token,
      domain: "ebay.com" # eBay doesn't have per-shop domains like Shopify
    )
  rescue => e
    Rails.logger.error "eBay token exchange failed: #{e.message}"
    raise StandardError, "Failed to create eBay account: #{e.message}"
  end

  private

  def request_access_token
    # eBay OAuth token exchange
    token_url = @sandbox ? "https://api.sandbox.ebay.com/identity/v1/oauth2/token" : "https://api.ebay.com/identity/v1/oauth2/token"
    
    RestClient.post(
      token_url,
      {
        grant_type: "authorization_code",
        code: @params["code"],
        redirect_uri: @redirect_uri
      },
      {
        "Authorization" => "Basic #{auth_header}",
        "Content-Type" => "application/x-www-form-urlencoded"
      }
    )
  end

  def auth_header
    # eBay requires Basic auth with base64 encoded client_id:client_secret
    credentials = "#{@client_id}:#{@client_secret}"
    Base64.strict_encode64(credentials)
  end

  def scopes
    # eBay OAuth scopes for inventory management
    scopes_array = [
      "https://api.ebay.com/oauth/api_scope",
      "https://api.ebay.com/oauth/api_scope/sell.marketing.readonly", 
      "https://api.ebay.com/oauth/api_scope/sell.marketing",
      "https://api.ebay.com/oauth/api_scope/sell.inventory.readonly",
      "https://api.ebay.com/oauth/api_scope/sell.inventory"
    ]
    scopes_array.join(" ")
  end

  def generate_state(user)
    return nil if user.nil?
    
    state = SecureRandom.hex(16)
    user.update(state_nonce: state)
    payload = {
      user_id: user.id,
      current_account_id: user.accounts.first.id,
      nonce: state,
      exp: 10.minutes.from_now.to_i
    }
    secret = Rails.application.credentials.secret_key_base
    JWT.encode(payload, secret, "HS256")
  end
end