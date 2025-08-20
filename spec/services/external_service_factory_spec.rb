require 'rails_helper'

RSpec.describe ExternalServiceFactory, type: :service do
  describe '.for' do
    context 'with Shopify external account' do
      let(:shopify_account) { create(:external_account, service_name: "shopify", domain: "test-shop.myshopify.com") }
      
      before do
        # Mock ShopifyAPI setup to avoid API calls during testing
        allow(ShopifyAPI::Context).to receive(:setup)
        allow(ShopifyAPI::Auth::Session).to receive(:new).and_return(double)
        allow(ShopifyAPI::Clients::Rest::Admin).to receive(:new).and_return(double)
      end

      it 'returns ShopifyService instance' do
        result = ExternalServiceFactory.for(shopify_account)
        expect(result).to be_a(ShopifyService)
      end

      it 'passes external_account to service' do
        result = ExternalServiceFactory.for(shopify_account)
        expect(result.instance_variable_get(:@external_account)).to eq(shopify_account)
      end
    end

    context 'with eBay external account' do
      let(:ebay_account) { create(:external_account, service_name: "ebay", domain: "ebay.com") }

      before do
        # Mock Rails credentials for eBay
        allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return("ebay_client_id")
        allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return("ebay_client_secret")
      end

      it 'returns EbayService instance' do
        result = ExternalServiceFactory.for(ebay_account)
        expect(result).to be_a(EbayService)
      end

      it 'passes external_account to service' do
        result = ExternalServiceFactory.for(ebay_account)
        expect(result.instance_variable_get(:@external_account)).to eq(ebay_account)
      end
    end

    context 'with unknown service' do
      let(:unknown_account) { build(:external_account, service_name: "unknown_service") }

      it 'raises ArgumentError' do
        # Bypass validation to test factory logic
        allow(unknown_account).to receive(:service_name).and_return("unknown_service")
        
        expect {
          ExternalServiceFactory.for(unknown_account)
        }.to raise_error(ArgumentError, "Unknown service: unknown_service")
      end
    end

    context 'service instantiation' do
      let(:shopify_account) { create(:external_account, service_name: "shopify", domain: "test-shop.myshopify.com") }
      let(:ebay_account) { create(:external_account, service_name: "ebay", domain: "ebay.com") }

      before do
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return("ebay_client_id")
        allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return("ebay_client_secret")
        
        # Mock ShopifyAPI setup for mixed service tests
        allow(ShopifyAPI::Context).to receive(:setup)
        allow(ShopifyAPI::Auth::Session).to receive(:new).and_return(double)
        allow(ShopifyAPI::Clients::Rest::Admin).to receive(:new).and_return(double)
      end

      it 'creates different service instances for different accounts' do
        shopify_service = ExternalServiceFactory.for(shopify_account)
        ebay_service = ExternalServiceFactory.for(ebay_account)

        expect(shopify_service).to be_a(ShopifyService)
        expect(ebay_service).to be_a(EbayService)
        expect(shopify_service).not_to eq(ebay_service)
      end

      it 'ensures services inherit from BaseExternalService' do
        shopify_service = ExternalServiceFactory.for(shopify_account)
        ebay_service = ExternalServiceFactory.for(ebay_account)

        expect(shopify_service).to be_a(BaseExternalService)
        expect(ebay_service).to be_a(BaseExternalService)
      end

      it 'ensures services implement required interface' do
        shopify_service = ExternalServiceFactory.for(shopify_account)
        ebay_service = ExternalServiceFactory.for(ebay_account)

        %i[publish_product remove_product get_products].each do |method|
          expect(shopify_service).to respond_to(method)
          expect(ebay_service).to respond_to(method)
        end
      end
    end
  end
end