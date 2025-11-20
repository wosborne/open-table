class ShopifyWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: [ :receive ]

  def receive
    unless valid_shopify_hmac?(request)
      render plain: "Unauthorized", status: :unauthorized and return
    end

    ShopifyAPI::Webhooks::Registry.process(
      ShopifyAPI::Webhooks::Request.new(raw_body: request.raw_post, headers: request.headers.to_h)
    )
    render json: { success: true }
  end

  private

  def valid_shopify_hmac?(request)
    hmac_header = request.headers["X-Shopify-Hmac-Sha256"]
    return false if hmac_header.nil?

    body = request.raw_post
    secret = Rails.application.credentials.shopify[:client_secret]

    digest = OpenSSL::Digest::SHA256.new
    calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest(digest, secret, body))

    ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
  end
end
