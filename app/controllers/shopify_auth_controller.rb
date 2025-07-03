require "securerandom"

class ShopifyAuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :callback ]

  # Redirects to Shopify OAuth URL
  # Example: https://naoaz-test-store.myshopify.com/admin/oauth/authorize?client_id=your_client_id&scope=read_products,write_products&redirect_uri=https://yourapp.com/shopify_auth/callback
  def oauth_redirect
    shop = params[:shop] || "naoaz-test-store.myshopify.com" # e.g., "userstore.myshopify.com"
    return render plain: "Missing shop parameter" unless shop.present?

    scopes = "read_products,write_products,read_inventory,write_inventory"
    redirect_uri = "https://f7e0-91-125-14-171.ngrok-free.app/shopify_auth/callback"

    oauth_url = "https://#{shop}/admin/oauth/authorize?" +
      "client_id=#{Rails.application.credentials.shopify[:client_id]}&" +
      "scope=#{scopes}&" +
      "redirect_uri=#{CGI.escape(redirect_uri)}&" +
      "state=#{generate_state}&" +
      "grant_options[]=per-user"

    redirect_to oauth_url, allow_other_host: true
  end

  def callback
    state = decode_state(params["state"])
    user = User.find_by(id: state["user_id"], state_nonce: state["nonce"])

    if user
      response = RestClient.post "https://#{params["shop"]}/admin/oauth/access_token",
      {
        client_id: Rails.application.credentials.shopify[:client_id],
        client_secret: Rails.application.credentials.shopify[:client_secret],
        code: params["code"]
      }

      access_token = JSON.parse(response.body)["access_token"]
      user.accounts.first.external_accounts.find_by(service_name: "shopify")&.destroy
      user.accounts.first.external_accounts.create(service_name: "shopify", api_token: access_token, domain: params["shop"])
      redirect_to account_tables_path(user.accounts.first.slug), notice: "Shopify account connected successfully!"
    else
      redirect_to root_path
    end
  end

  private

  def generate_state
    state = SecureRandom.hex(16)
    current_user&.update(state_nonce: state)
    payload = {
      user_id: current_user.id,
      current_account_id: current_user.accounts.first.id,
      nonce: state,
      exp: 10.minutes.from_now.to_i
    }
    secret = Rails.application.credentials.secret_key_base
    JWT.encode(payload, secret, "HS256")
  end

  def decode_state(token)
    secret = Rails.application.credentials.secret_key_base
    decoded_token = JWT.decode(token, secret, true, { algorithm: "HS256" })
    decoded_token.first  # returns payload hash
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil  # handle invalid token case
  end
end
