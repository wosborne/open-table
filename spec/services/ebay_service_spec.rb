require 'rails_helper'

RSpec.describe EbayService, type: :service do
  let(:external_account) { create(:external_account, service_name: "ebay", domain: "ebay.com", api_token: "ebay_access_token") }
  let(:ebay_service) { EbayService.new(external_account: external_account) }

  before do
    # Mock Rails credentials for eBay
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return("ebay_client_id")
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return("ebay_client_secret")
  end

  describe '#initialize' do
    it 'sets up the eBay service with external account' do
      expect(ebay_service.instance_variable_get(:@external_account)).to eq(external_account)
      expect(ebay_service.instance_variable_get(:@access_token)).to eq("ebay_access_token")
      expect(ebay_service.instance_variable_get(:@client_id)).to eq("ebay_client_id")
      expect(ebay_service.instance_variable_get(:@client_secret)).to eq("ebay_client_secret")
    end
  end

  describe '#get_products' do
    it 'returns empty array (TODO implementation)' do
      result = ebay_service.get_products
      expect(result).to eq([])
    end

    it 'calls with_token_refresh' do
      expect(ebay_service).to receive(:with_token_refresh).and_yield
      ebay_service.get_products
    end
  end

  describe '#publish_product' do
    let(:product_params) do
      {
        title: "iPhone 13 Pro",
        description: "Used iPhone in good condition",
        price: "599.99",
        sku: "IPHONE13PRO001"
      }
    end

    it 'returns mock eBay product response' do
      result = ebay_service.publish_product(product_params)
      
      expect(result).to be_a(Hash)
      expect(result["ItemID"]).to eq("123456789")
      expect(result["SKU"]).to eq("IPHONE13PRO001")
      expect(result["Title"]).to eq("iPhone 13 Pro")
    end

    it 'calls with_token_refresh' do
      expect(ebay_service).to receive(:with_token_refresh).and_yield
      ebay_service.publish_product(product_params)
    end

    it 'builds eBay item structure' do
      expect(ebay_service).to receive(:build_ebay_item).with(product_params).and_call_original
      ebay_service.publish_product(product_params)
    end
  end

  describe '#remove_product' do
    it 'returns true (TODO implementation)' do
      result = ebay_service.remove_product("123456789")
      expect(result).to be true
    end

    it 'calls with_token_refresh' do
      expect(ebay_service).to receive(:with_token_refresh).and_yield
      ebay_service.remove_product("123456789")
    end
  end

  describe '#token_expired?' do
    it 'detects token-related errors' do
      token_error = StandardError.new("Invalid token")
      result = ebay_service.send(:token_expired?, token_error)
      expect(result).to be true
    end

    it 'returns false for non-token errors' do
      other_error = StandardError.new("Network error")
      result = ebay_service.send(:token_expired?, other_error)
      expect(result).to be false
    end

    it 'returns false for non-StandardError types' do
      other_error = ArgumentError.new("Invalid argument")
      result = ebay_service.send(:token_expired?, other_error)
      expect(result).to be false
    end
  end

  describe '#refresh_access_token' do
    context 'with refresh token' do
      before do
        external_account.update!(refresh_token: 'ebay_refresh_token')
      end

      it 'returns false with refresh token present' do
        allow(ebay_service.send(:external_account)).to receive(:refresh_token).and_return('some_token')
        result = ebay_service.send(:refresh_access_token)
        expect(result).to be false
      end
    end

    context 'without refresh token' do
      before do
        external_account.update!(refresh_token: nil)
      end

      it 'returns false early' do
        result = ebay_service.send(:refresh_access_token)
        expect(result).to be false
      end
    end
  end

  describe '#build_ebay_item' do
    let(:product_params) do
      {
        title: "iPhone 13 Pro",
        description: "Used iPhone in good condition",
        price: "599.99"
      }
    end

    it 'builds correct eBay item structure' do
      result = ebay_service.send(:build_ebay_item, product_params)
      
      expect(result).to include(
        Title: "iPhone 13 Pro",
        Description: "Used iPhone in good condition",
        PrimaryCategory: { CategoryID: "166" },
        StartPrice: "599.99",
        ListingDuration: "Days_7",
        ListingType: "FixedPriceItem"
      )
    end

    it 'uses title as description when description is missing' do
      params_without_description = product_params.except(:description)
      result = ebay_service.send(:build_ebay_item, params_without_description)
      
      expect(result[:Description]).to eq("iPhone 13 Pro")
    end

    it 'defaults price when missing' do
      params_without_price = product_params.except(:price)
      result = ebay_service.send(:build_ebay_item, params_without_price)
      
      expect(result[:StartPrice]).to eq("0.99")
    end

    it 'uses default category for cell phones' do
      result = ebay_service.send(:build_ebay_item, product_params)
      expect(result[:PrimaryCategory][:CategoryID]).to eq("166")
    end

    it 'sets listing type to fixed price' do
      result = ebay_service.send(:build_ebay_item, product_params)
      expect(result[:ListingType]).to eq("FixedPriceItem")
    end

    it 'sets 7-day listing duration' do
      result = ebay_service.send(:build_ebay_item, product_params)
      expect(result[:ListingDuration]).to eq("Days_7")
    end
  end

  describe 'inheritance from BaseExternalService' do
    it 'inherits from BaseExternalService' do
      expect(EbayService.superclass).to eq(BaseExternalService)
    end

    it 'implements required abstract methods' do
      expect(ebay_service).to respond_to(:publish_product)
      expect(ebay_service).to respond_to(:remove_product)
      expect(ebay_service).to respond_to(:get_products)
    end

    it 'has access to with_token_refresh from base class' do
      expect(ebay_service.respond_to?(:with_token_refresh, true)).to be true
    end
  end

  describe 'error handling' do
    it 'handles errors in with_token_refresh wrapper' do
      # Mock an error that would trigger token refresh
      allow(ebay_service).to receive(:token_expired?).and_return(true)
      allow(ebay_service).to receive(:refresh_access_token).and_return(false)
      
      expect {
        ebay_service.send(:with_token_refresh) { raise StandardError.new("token error") }
      }.to raise_error(StandardError, "token error")
    end

    it 'retries once on token expiration if refresh succeeds' do
      call_count = 0
      allow(ebay_service).to receive(:token_expired?).and_return(true)
      allow(ebay_service).to receive(:refresh_access_token).and_return(true)
      
      result = ebay_service.send(:with_token_refresh) do
        call_count += 1
        if call_count == 1
          raise StandardError.new("token expired")
        else
          "success"
        end
      end
      
      expect(result).to eq("success")
      expect(call_count).to eq(2)
    end
  end
end