require 'rails_helper'

RSpec.describe ShopifyWebhooksController, type: :controller do
  let(:secret) { 'test_webhook_secret' }
  let(:webhook_payload) { { order: { id: 123, name: '#1001' } }.to_json }
  let(:calculated_hmac) { Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', secret, webhook_payload)) }

  before do
    allow(Rails.application.credentials.shopify).to receive(:[]).with(:client_secret).and_return(secret)
  end

  describe 'POST #receive' do
    context 'with valid HMAC signature' do
      before do
        request.headers['X-Shopify-Hmac-Sha256'] = calculated_hmac
        request.headers['Content-Type'] = 'application/json'
        request.headers['X-Shopify-Topic'] = 'orders/create'
        request.headers['X-Shopify-Shop-Domain'] = 'test-shop.myshopify.com'
      end

      it 'processes the webhook successfully' do
        mock_webhook_request = instance_double(ShopifyAPI::Webhooks::Request)
        allow(ShopifyAPI::Webhooks::Request).to receive(:new).and_return(mock_webhook_request)
        expect(ShopifyAPI::Webhooks::Registry).to receive(:process).with(mock_webhook_request)

        post :receive, body: webhook_payload

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'success' => true })
      end

      it 'creates webhook request with correct parameters' do
        expect(ShopifyAPI::Webhooks::Request).to receive(:new).with(
          raw_body: webhook_payload,
          headers: hash_including(
            'HTTP_X_SHOPIFY_HMAC_SHA256' => calculated_hmac,
            'HTTP_X_SHOPIFY_TOPIC' => 'orders/create',
            'HTTP_X_SHOPIFY_SHOP_DOMAIN' => 'test-shop.myshopify.com'
          )
        )

        allow(ShopifyAPI::Webhooks::Registry).to receive(:process)

        post :receive, body: webhook_payload
      end

      it 'bypasses authentication and CSRF protection' do
        # This test ensures the skip_before_action callbacks work
        expect(controller).not_to receive(:authenticate_user!)
        expect(controller).not_to receive(:verify_authenticity_token)

        allow(ShopifyAPI::Webhooks::Registry).to receive(:process)
        post :receive, body: webhook_payload

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid HMAC signature' do
      before do
        request.headers['X-Shopify-Hmac-Sha256'] = 'invalid_signature'
        request.headers['Content-Type'] = 'application/json'
      end

      it 'returns unauthorized status' do
        post :receive, body: webhook_payload

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to eq('Unauthorized')
      end

      it 'does not process the webhook' do
        expect(ShopifyAPI::Webhooks::Registry).not_to receive(:process)

        post :receive, body: webhook_payload
      end
    end

    context 'with missing HMAC header' do
      before do
        request.headers['Content-Type'] = 'application/json'
      end

      it 'returns unauthorized status' do
        post :receive, body: webhook_payload

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to eq('Unauthorized')
      end
    end

    context 'HMAC validation' do
      it 'validates HMAC correctly for different payloads' do
        different_payload = { order: { id: 456, name: '#1002' } }.to_json
        different_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', secret, different_payload))

        request.headers['X-Shopify-Hmac-Sha256'] = different_hmac
        request.headers['X-Shopify-Topic'] = 'orders/create'
        request.headers['X-Shopify-Shop-Domain'] = 'test-shop.myshopify.com'
        allow(ShopifyAPI::Webhooks::Registry).to receive(:process)

        post :receive, body: different_payload

        expect(response).to have_http_status(:ok)
      end

      it 'fails validation with wrong secret' do
        wrong_secret_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', 'wrong_secret', webhook_payload))
        request.headers['X-Shopify-Hmac-Sha256'] = wrong_secret_hmac

        post :receive, body: webhook_payload

        expect(response).to have_http_status(:unauthorized)
      end

      it 'uses secure comparison for HMAC validation' do
        request.headers['X-Shopify-Hmac-Sha256'] = calculated_hmac
        request.headers['X-Shopify-Topic'] = 'orders/create'
        request.headers['X-Shopify-Shop-Domain'] = 'test-shop.myshopify.com'

        expect(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original
        allow(ShopifyAPI::Webhooks::Registry).to receive(:process)

        post :receive, body: webhook_payload
      end
    end

    context 'error handling' do
      before do
        request.headers['X-Shopify-Hmac-Sha256'] = calculated_hmac
        request.headers['X-Shopify-Topic'] = 'orders/create'
        request.headers['X-Shopify-Shop-Domain'] = 'test-shop.myshopify.com'
      end

      it 'handles webhook processing errors gracefully' do
        allow(ShopifyAPI::Webhooks::Registry).to receive(:process).and_raise(StandardError, "Processing failed")

        expect {
          post :receive, body: webhook_payload
        }.to raise_error(StandardError, "Processing failed")
      end
    end
  end

  describe 'private methods' do
    describe '#valid_shopify_hmac?' do
      let(:mock_request) do
        double(
          headers: { 'X-Shopify-Hmac-Sha256' => calculated_hmac },
          raw_post: webhook_payload
        )
      end

      it 'validates HMAC correctly' do
        result = controller.send(:valid_shopify_hmac?, mock_request)
        expect(result).to be true
      end

      it 'rejects invalid HMAC' do
        invalid_request = double(
          headers: { 'X-Shopify-Hmac-Sha256' => 'invalid' },
          raw_post: webhook_payload
        )

        result = controller.send(:valid_shopify_hmac?, invalid_request)
        expect(result).to be false
      end

      it 'handles missing HMAC header' do
        no_hmac_request = double(
          headers: {},
          raw_post: webhook_payload
        )

        result = controller.send(:valid_shopify_hmac?, no_hmac_request)
        expect(result).to be false
      end
    end
  end
end
