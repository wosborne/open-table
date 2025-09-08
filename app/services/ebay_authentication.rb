require "securerandom"

class EbayAuthentication
  def initialize(params: nil)
    @params = params
    @api_base_url = Rails.application.credentials.ebay.api_base_url
    @client_id = Rails.application.credentials.ebay.client_id
    @client_secret = Rails.application.credentials.ebay.client_secret
    @redirect_uri = Rails.application.credentials.ebay.redirect_url
  end

  def authentication_path(user)
    state = generate_state(user)
    auth_base_url = @api_base_url.gsub("api.", "auth.")

    "#{auth_base_url}/oauth2/authorize?" +
      "client_id=#{@client_id}&" +
      "response_type=code&" +
      "redirect_uri=#{CGI.escape(@redirect_uri)}&" +
      "scope=#{CGI.escape(scopes)}&" +
      "state=#{state}"
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

    # Create the external account
    external_account = user.accounts.first.external_accounts.create!(
      service_name: "ebay",
      api_token: access_token,
      refresh_token: refresh_token,
      domain: "ebay.com" # eBay doesn't have per-shop domains like Shopify
    )

    # Fetch and store eBay user information
    begin
      ebay_service = EbayService.new(external_account: external_account)
      user_info = ebay_service.get_user_info
      
      if user_info.present?
        Rails.logger.info "Fetched eBay user info: #{user_info.keys.join(', ')}"
        external_account.update!(
          ebay_user_id: user_info[:user_id],
          ebay_username: user_info[:username],
          ebay_display_name: user_info[:display_name] || [user_info[:first_name], user_info[:last_name]].compact.join(' '),
          ebay_email: user_info[:email]
        )
        Rails.logger.info "Stored eBay user info for account: #{user_info[:username] || user_info[:display_name] || user_info[:user_id]}"
      else
        Rails.logger.warn "No eBay user info returned from API"
      end
    rescue => user_info_error
      Rails.logger.warn "Could not fetch eBay user info during authentication: #{user_info_error.message}"
      # Don't fail the authentication if user info fetch fails
    end

    external_account
  rescue => e
    Rails.logger.error "eBay token exchange failed: #{e.message}"
    raise StandardError, "Failed to create eBay account: #{e.message}"
  end

  private

  def request_access_token
    Rails.logger.info "eBay OAuth token exchange request:"
    Rails.logger.info "  URL: #{@api_base_url}/identity/v1/oauth2/token"
    Rails.logger.info "  Code: #{@params["code"]}"
    Rails.logger.info "  Redirect URI: #{@redirect_uri}"
    Rails.logger.info "  Client ID: #{@client_id}"
    Rails.logger.info "  Auth header: Basic #{auth_header}"

    response = RestClient.post(
      "#{@api_base_url}/identity/v1/oauth2/token",
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

    Rails.logger.info "eBay OAuth response: #{response.code} - #{response.body}"
    response
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error "eBay OAuth error: #{e.response&.code} - #{e.response&.body}"
    raise
  end

  def auth_header
    # eBay requires Basic auth with base64 encoded client_id:client_secret
    credentials = "#{@client_id}:#{@client_secret}"
    Base64.strict_encode64(credentials)
  end

  def scopes
    # eBay OAuth scopes for inventory management and user identity
    scopes_array = [
      "https://api.ebay.com/oauth/api_scope",
      "https://api.ebay.com/oauth/api_scope/sell.marketing.readonly",
      "https://api.ebay.com/oauth/api_scope/sell.marketing",
      "https://api.ebay.com/oauth/api_scope/sell.inventory.readonly",
      "https://api.ebay.com/oauth/api_scope/sell.inventory",
      "https://api.ebay.com/oauth/api_scope/sell.account",
      "https://api.ebay.com/oauth/api_scope/sell.fulfillment",
      "https://api.ebay.com/oauth/api_scope/commerce.identity.readonly"
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
