require 'rails_helper'

RSpec.describe ShopifyService, type: :service do
  let(:shop_domain) { "test-shop.myshopify.com" }
  let(:access_token) { "test_access_token" }
  let(:external_account) { create(:external_account, service_name: "shopify", domain: shop_domain, api_token: access_token) }
  let(:shopify_service) { ShopifyService.new(external_account: external_account, shop_domain: shop_domain, access_token: access_token) }
  
  let(:mock_session) { instance_double(ShopifyAPI::Clients::Rest::Admin) }
  let(:success_response) { double(code: 201, body: { "product" => { "id" => 123, "title" => "Test Product" } }) }
  let(:error_response) { double(code: 400, body: { "errors" => "Invalid request" }) }

  before do
    # Mock ShopifyAPI setup for this specific service
    allow(ShopifyAPI::Clients::Rest::Admin).to receive(:new).and_return(mock_session)
    allow(ShopifyAPI::Auth::Session).to receive(:new).and_return(double)
  end

  describe '#initialize' do
    it 'sets up the Shopify session' do
      expect(ShopifyAPI::Context).to receive(:setup).with(
        api_key: Rails.application.credentials.shopify[:client_id],
        api_secret_key: Rails.application.credentials.shopify[:client_secret],
        host_name: shop_domain,
        api_version: "2024-04",
        is_embedded: false,
        is_private: false
      )
      
      ShopifyService.new(external_account: external_account, shop_domain: shop_domain, access_token: access_token)
    end

    it 'creates a REST admin client' do
      expect(ShopifyAPI::Clients::Rest::Admin).to receive(:new)
      
      ShopifyService.new(external_account: external_account, shop_domain: shop_domain, access_token: access_token)
    end
  end

  describe '#get_products' do
    let(:products_response) { double(body: { "products" => [{ "id" => 1, "title" => "Product 1" }] }) }

    it 'fetches products from Shopify' do
      expect(mock_session).to receive(:get).with(path: "products").and_return(products_response)
      
      result = shopify_service.get_products
      expect(result).to eq([{ "id" => 1, "title" => "Product 1" }])
    end

    it 'can call refresh_access_token when needed' do
      # Test that the private method exists and can be called
      expect(shopify_service.respond_to?(:refresh_access_token, true)).to be true
      
      # Test the actual method works with mocked external account
      allow(external_account).to receive(:refresh_token).and_return('test_refresh_token')
      allow(HTTParty).to receive(:post).and_return(double(success?: true, parsed_response: { 'access_token' => 'new_token' }))
      allow(external_account).to receive(:update!)
      
      result = shopify_service.send(:refresh_access_token)
      expect(result).to be true
    end
  end

  describe '#publish_product' do
    context 'creating a new product' do
      let(:product_params) { { title: "New Product", variants: [] } }

      it 'creates a product successfully' do
        expect(mock_session).to receive(:post).with(
          path: "products",
          body: { product: product_params }
        ).and_return(success_response)

        result = shopify_service.publish_product(product_params)
        expect(result).to eq({ "id" => 123, "title" => "Test Product" })
      end

      it 'raises error on failed creation' do
        expect(mock_session).to receive(:post).and_return(error_response)

        expect {
          shopify_service.publish_product(product_params)
        }.to raise_error(StandardError, /Error creating product/)
      end
    end

    context 'updating existing product' do
      let(:product_params) { { id: 123, title: "Updated Product", variants: [] } }

      it 'updates a product successfully' do
        update_response = double(code: 200, body: { "product" => { "id" => 123, "title" => "Updated Product" } })
        expect(mock_session).to receive(:put).with(
          path: "products/123",
          body: { product: { title: "Updated Product", variants: [] } }
        ).and_return(update_response)

        result = shopify_service.publish_product(product_params)
        expect(result).to eq({ "id" => 123, "title" => "Updated Product" })
      end

      it 'raises error on failed update' do
        expect(mock_session).to receive(:put).and_return(error_response)

        expect {
          shopify_service.publish_product(product_params)
        }.to raise_error(StandardError, /Error updating product/)
      end
    end

    it 'publishes product with all variants as received' do
      product_params = {
        title: "Test Product",
        variants: [
          { sku: "VALID", option1: "Red", option2: "Small", price: 10 },
          { sku: "ANOTHER", option1: "Blue", option2: "Large", price: 20 }
        ]
      }

      expect(mock_session).to receive(:post).with(
        path: "products",
        body: { product: product_params }
      ).and_return(success_response)

      shopify_service.publish_product(product_params)
    end
  end

  describe '#remove_product' do
    it 'deletes a product successfully' do
      delete_response = double(code: 200)
      expect(mock_session).to receive(:delete).with(path: "products/123").and_return(delete_response)

      result = shopify_service.remove_product(123)
      expect(result).to be true
    end

    it 'returns true for 204 response' do
      delete_response = double(code: 204)
      expect(mock_session).to receive(:delete).and_return(delete_response)

      result = shopify_service.remove_product(123)
      expect(result).to be true
    end

    it 'returns false for error response' do
      delete_response = double(code: 404)
      expect(mock_session).to receive(:delete).and_return(delete_response)

      result = shopify_service.remove_product(123)
      expect(result).to be false
    end
  end

  describe '#refresh_access_token' do
    let(:refresh_response) { double(success?: true, parsed_response: { 'access_token' => 'new_token' }) }

    before do
      external_account.update!(refresh_token: 'refresh_token_123')
    end

    it 'refreshes the access token successfully' do
      # Override the global mock for this specific test
      allow(HTTParty).to receive(:post).with(
        "https://#{shop_domain}/admin/oauth/access_token",
        {
          body: {
            client_id: Rails.application.credentials.shopify[:client_id],
            client_secret: Rails.application.credentials.shopify[:client_secret],
            refresh_token: 'refresh_token_123',
            grant_type: 'refresh_token'
          },
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
        }
      ).and_return(refresh_response)

      expect(external_account).to receive(:update!).with(api_token: 'new_token')

      result = shopify_service.send(:refresh_access_token)
      expect(result).to be true
    end

    it 'returns false on failed refresh' do
      failed_response = double(success?: false)
      # Override the global mock for this specific test
      allow(HTTParty).to receive(:post).and_return(failed_response)

      result = shopify_service.send(:refresh_access_token)
      expect(result).to be false
    end

    it 'returns false when no refresh token' do
      external_account.update!(refresh_token: nil)

      result = shopify_service.send(:refresh_access_token)
      expect(result).to be_falsey
    end
  end

  describe 'with_token_refresh wrapper' do
    it 'calls the block when no errors occur' do
      expect(mock_session).to receive(:get).and_return(double(body: { "products" => [] }))
      
      result = shopify_service.get_products
      expect(result).to eq([])
    end

    it 'has the with_token_refresh method available' do
      expect(shopify_service.respond_to?(:with_token_refresh, true)).to be true
    end
  end
end