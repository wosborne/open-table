require 'rails_helper'

RSpec.describe BaseExternalService, type: :service do
  let(:external_account) { build(:external_account, service_name: "test", domain: "test.com", api_token: "test_token") }
  let(:service) { BaseExternalService.new(external_account: external_account) }

  describe '#initialize' do
    it 'sets instance variables from external account' do
      expect(service.instance_variable_get(:@external_account)).to eq(external_account)
      expect(service.instance_variable_get(:@domain)).to eq("test.com")
      expect(service.instance_variable_get(:@access_token)).to eq("test_token")
    end
  end

  describe 'abstract methods' do
    it 'raises NotImplementedError for publish_product' do
      expect {
        service.publish_product({})
      }.to raise_error(NotImplementedError, "Subclasses must implement #publish_product")
    end

    it 'raises NotImplementedError for remove_product' do
      expect {
        service.remove_product("123")
      }.to raise_error(NotImplementedError, "Subclasses must implement #remove_product")
    end

    it 'raises NotImplementedError for get_products' do
      expect {
        service.get_products
      }.to raise_error(NotImplementedError, "Subclasses must implement #get_products")
    end
  end

  describe 'protected methods' do
    it 'provides access to external_account via attr_reader' do
      expect(service.send(:external_account)).to eq(external_account)
    end

    it 'provides access to domain via attr_reader' do
      expect(service.send(:domain)).to eq("test.com")
    end

    it 'provides access to access_token via attr_reader' do
      expect(service.send(:access_token)).to eq("test_token")
    end
  end

  describe '#with_token_refresh' do
    it 'executes block when no errors occur' do
      result = service.send(:with_token_refresh) { "success" }
      expect(result).to eq("success")
    end

    it 'calls token_expired? when error occurs' do
      error = StandardError.new("test error")
      allow(service).to receive(:token_expired?).with(error).and_return(false)

      expect {
        service.send(:with_token_refresh) { raise error }
      }.to raise_error(StandardError, "test error")

      expect(service).to have_received(:token_expired?).with(error)
    end

    it 'calls refresh_access_token when token is expired' do
      error = StandardError.new("token expired")
      allow(service).to receive(:token_expired?).with(error).and_return(true)
      allow(service).to receive(:refresh_access_token).and_return(false)

      expect {
        service.send(:with_token_refresh) { raise error }
      }.to raise_error(StandardError, "token expired")

      expect(service).to have_received(:refresh_access_token)
    end

    it 'retries block once when token refresh succeeds' do
      call_count = 0
      error = StandardError.new("token expired")
      
      allow(service).to receive(:token_expired?).with(error).and_return(true)
      allow(service).to receive(:refresh_access_token).and_return(true)

      result = service.send(:with_token_refresh) do
        call_count += 1
        if call_count == 1
          raise error
        else
          "success after refresh"
        end
      end

      expect(result).to eq("success after refresh")
      expect(call_count).to eq(2)
    end

    it 'does not retry when token refresh fails' do
      call_count = 0
      error = StandardError.new("token expired")
      
      allow(service).to receive(:token_expired?).with(error).and_return(true)
      allow(service).to receive(:refresh_access_token).and_return(false)

      expect {
        service.send(:with_token_refresh) do
          call_count += 1
          raise error
        end
      }.to raise_error(StandardError, "token expired")

      expect(call_count).to eq(1)
    end

    it 're-raises error when token is not expired' do
      error = StandardError.new("network error")
      allow(service).to receive(:token_expired?).with(error).and_return(false)

      expect {
        service.send(:with_token_refresh) { raise error }
      }.to raise_error(StandardError, "network error")
    end
  end

  describe 'abstract protected methods' do
    it 'raises NotImplementedError for token_expired?' do
      expect {
        service.send(:token_expired?, StandardError.new)
      }.to raise_error(NotImplementedError, "Subclasses must implement #token_expired?")
    end

    it 'raises NotImplementedError for refresh_access_token' do
      expect {
        service.send(:refresh_access_token)
      }.to raise_error(NotImplementedError, "Subclasses must implement #refresh_access_token")
    end
  end

  # Test that subclasses can properly implement the interface
  describe 'subclass implementation example' do
    let(:test_service_class) do
      Class.new(BaseExternalService) do
        def publish_product(product_params)
          { id: "123", title: product_params[:title] }
        end

        def remove_product(product_id)
          product_id == "123"
        end

        def get_products
          [{ id: "123", title: "Test Product" }]
        end

        protected

        def token_expired?(error)
          error.message.include?("expired")
        end

        def refresh_access_token
          true
        end
      end
    end

    let(:test_service) { test_service_class.new(external_account: external_account) }

    it 'allows subclasses to implement abstract methods' do
      expect(test_service.publish_product(title: "Test")).to eq({ id: "123", title: "Test" })
      expect(test_service.remove_product("123")).to be true
      expect(test_service.get_products).to eq([{ id: "123", title: "Test Product" }])
    end

    it 'allows subclasses to implement token handling' do
      expect(test_service.send(:token_expired?, StandardError.new("token expired"))).to be true
      expect(test_service.send(:token_expired?, StandardError.new("network error"))).to be false
      expect(test_service.send(:refresh_access_token)).to be true
    end

    it 'works with with_token_refresh in subclass' do
      call_count = 0
      result = test_service.send(:with_token_refresh) do
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