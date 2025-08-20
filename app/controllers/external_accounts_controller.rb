class ExternalAccountsController < AccountsController
  skip_before_action :authenticate_user!, only: [ :shopify_callback, :ebay_callback, :ebay_auth ]
  skip_before_action :find_account, only: [ :shopify_callback, :ebay_callback, :ebay_auth ]
  skip_before_action :verify_authenticity_token, only: [ :ebay_callback, :ebay_auth ]

  def new
    @external_account = ExternalAccount.new
  end

  def create
    begin
      case external_account_params[:service_name]
      when "shopify"
        shopify_auth = ShopifyAuthentication.new
        auth_path = shopify_auth.authentication_path(current_user, external_account_params[:domain])
        redirect_to auth_path, allow_other_host: true
      when "ebay"
        # Generate unique state and store user ID in cache (not session)
        state = SecureRandom.hex(32)
        Rails.cache.write("ebay_oauth_state_#{state}", current_user.id, expires_in: 10.minutes)
        session[:ebay_oauth_state] = state
        redirect_to "/auth/ebay_oauth", allow_other_host: true
      else
        redirect_to new_account_external_account_path(current_account), alert: "Invalid service name"
      end
    rescue => e
      Rails.logger.error "External account creation error: #{e.message}"
      redirect_to new_account_external_account_path(current_account), alert: "Failed to initiate authentication: #{e.message}"
    end
  end

  def shopify_callback
    shopify_auth = ShopifyAuthentication.new(params:)
    state = shopify_auth.decode_state(params["state"])
    user = User.find_by(id: state["user_id"], state_nonce: state["nonce"])

    if user
      shopify_auth.create_external_account_for(user)

      redirect_to account_tables_path(user.accounts.first), notice: "Shopify account connected successfully!"
    else
      redirect_to new_account_external_account_path(user.accounts.first), alert: "User not found"
    end
  end

  def ebay_callback
    # Get user ID from cache using the state parameter
    state = params[:state]
    user_id = Rails.cache.read("ebay_oauth_state_#{state}") if state
    user = User.find_by(id: user_id) if user_id
    
    # Debug logging
    Rails.logger.info "Callback params state: #{params[:state]}"
    Rails.logger.info "User ID from cache: #{user_id}"
    Rails.logger.info "User found: #{user&.id}"
    
    # Verify state parameter exists and user found
    if !user_id || !user
      Rails.logger.error "Invalid state or user not found: state=#{state}, user_id=#{user_id}"
      redirect_to root_path, alert: "Invalid authentication state"
      return
    end

    if user && params[:code]
      begin
        Rails.logger.info "Starting token exchange with code: #{params[:code][0..20]}..."
        # Exchange authorization code for access token
        token_response = exchange_code_for_token(params[:code])
        Rails.logger.info "Token exchange successful: #{token_response.keys}"
        
        # Remove existing eBay account for this user
        existing_account = user.accounts.first.external_accounts.find_by(service_name: "ebay")
        if existing_account
          Rails.logger.info "Removing existing eBay account: #{existing_account.id}"
          existing_account.destroy
        end
        
        # Create external account with token data
        external_account = user.accounts.first.external_accounts.create!(
          service_name: "ebay",
          api_token: token_response["access_token"],
          refresh_token: token_response["refresh_token"],
          domain: "ebay.com"
        )
        Rails.logger.info "Created external account: #{external_account.id}"

        # Clear cache (one-time use for security)
        Rails.cache.delete("ebay_oauth_state_#{state}")
        session.delete(:ebay_oauth_state)
        
        # Sign the user back in since the callback loses the authentication context
        sign_in user

        redirect_to account_tables_path(user.accounts.first), notice: "eBay account connected successfully!"
      rescue => e
        Rails.logger.error "eBay token exchange failed: #{e.message}"
        Rails.logger.error "eBay token exchange error backtrace: #{e.backtrace.first(10).join("\n")}"
        Rails.cache.delete("ebay_oauth_state_#{state}")
        session.delete(:ebay_oauth_state)
        redirect_to root_path, alert: "eBay authentication failed: #{e.message}"
      end
    else
      Rails.logger.error "eBay callback failed: user=#{user&.id}, code=#{params[:code].present?}"
      Rails.cache.delete("ebay_oauth_state_#{state}") if state
      session.delete(:ebay_oauth_state)
      redirect_to root_path, alert: "eBay authentication failed"
    end
  end

  def ebay_auth
    # Get the pre-generated state from session
    state = session[:ebay_oauth_state]
    
    if state
      client_id = Rails.application.credentials.dig(:ebay, :client_id)
      # Always use the configured redirect URI from credentials (which should be the ngrok URL)
      redirect_uri = Rails.application.credentials.dig(:ebay, :redirect_url)
      sandbox = Rails.env.development? || Rails.env.test?
      
      # Try with minimal scope first - URL encode it properly
      scopes = "https://api.ebay.com/oauth/api_scope"
      
      base_url = sandbox ? "https://auth.sandbox.ebay.com/oauth2/authorize" : "https://auth.ebay.com/oauth2/authorize"
      
      oauth_url = "#{base_url}?" + {
        client_id: client_id,
        response_type: 'code',
        redirect_uri: redirect_uri,
        scope: scopes,
        state: state
      }.to_query
      
      # Debug logging
      Rails.logger.info "eBay OAuth URL: #{oauth_url}"
      Rails.logger.info "Client ID: #{client_id}"
      Rails.logger.info "Client Secret: #{Rails.application.credentials.dig(:ebay, :client_secret)&.first(10)}..."
      Rails.logger.info "Redirect URI: #{redirect_uri}"
      Rails.logger.info "Scopes: #{scopes}"
      Rails.logger.info "Sandbox mode: #{sandbox}"
      Rails.logger.info "State: #{state}"
      
      redirect_to oauth_url, allow_other_host: true
    else
      redirect_to root_path, alert: "Session expired, please try again"
    end
  end

  def destroy
    @external_account = current_account.external_accounts.find(params[:id])
    @external_account.destroy
    redirect_to edit_account_path(current_account), notice: "External account disconnected successfully!"
  end

  private

  def exchange_code_for_token(authorization_code)
    client_id = Rails.application.credentials.dig(:ebay, :client_id)
    client_secret = Rails.application.credentials.dig(:ebay, :client_secret)
    # Always use the configured redirect URI from credentials (which should be the ngrok URL)
    redirect_uri = Rails.application.credentials.dig(:ebay, :redirect_url)
    sandbox = Rails.env.development? || Rails.env.test?
    
    token_url = sandbox ? "https://api.sandbox.ebay.com/identity/v1/oauth2/token" : "https://api.ebay.com/identity/v1/oauth2/token"
    
    response = RestClient.post(
      token_url,
      {
        grant_type: "authorization_code",
        code: authorization_code,
        redirect_uri: redirect_uri
      },
      {
        "Authorization" => "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}",
        "Content-Type" => "application/x-www-form-urlencoded"
      }
    )
    
    JSON.parse(response.body)
  end

  def external_account_params
    params.require(:external_account).permit(:service_name, :domain)
  end
end
