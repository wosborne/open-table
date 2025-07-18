require "securerandom"

class ShopifyAuthentication
  def initialize(params: nil)
    @params = params
  end

  def authentication_path(user, shop)
    "https://#{shop}/admin/oauth/authorize?" +
      "client_id=#{Rails.application.credentials.shopify[:client_id]}&" +
      "scope=#{scopes}&" +
      "redirect_uri=#{Rails.application.credentials.shopify[:redirect_url]}&" +
      "state=#{generate_state(user)}&" +
      "grant_options[]=per-user"
  end

  def decode_state(state)
    secret = Rails.application.credentials.secret_key_base
    decoded_token = JWT.decode(state, secret, true, { algorithm: "HS256" })
    decoded_token.first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil  # handle invalid token case
  end

  def create_external_account_for(user)
    token_response = JSON.parse(request_access_token.body)
    access_token = token_response["access_token"]
    refresh_token = token_response["refresh_token"]

    user.accounts.first.external_accounts.find_by(service_name: "shopify")&.destroy
    user.accounts.first.external_accounts.create(
      service_name: "shopify", 
      api_token: access_token, 
      refresh_token: refresh_token,
      domain: @params["shop"]
    )
  end

  private

  def request_access_token
    RestClient.post(
      "https://#{@params["shop"]}/admin/oauth/access_token",
      {
        client_id: Rails.application.credentials.shopify[:client_id],
        client_secret: Rails.application.credentials.shopify[:client_secret],
        code: @params["code"]
      }
    )
  end

  def scopes
    "read_products,write_products,read_inventory,write_inventory,read_orders"
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
