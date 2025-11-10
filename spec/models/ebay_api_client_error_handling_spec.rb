require 'rails_helper'

RSpec.describe EbayApiClient, 'Error Handling', type: :model do
  include EbayApiMocking

  let(:external_account) { create(:external_account, :ebay) }
  let(:client) { described_class.new(external_account) }
  
  let(:policy_data) do
    {
      name: "Test Policy",
      marketplaceId: "EBAY_GB",
      categoryTypes: [{ name: "ALL_EXCLUDING_MOTORS_VEHICLES", default: true }]
    }
  end

  before do
    mock_ebay_api_responses

    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :api_base_url).and_return('https://api.ebay.com')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return('test_client_id')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return('test_client_secret')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :token_url).and_return('https://api.ebay.com/identity/v1/oauth2/token')

    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe 'Error Classification via Exception System' do
    context 'when eBay returns 401 Unauthorized' do
      let(:error_response) do
        EbayApiResponse.new(
          success: false,
          status_code: 401,
          error: { "errors" => [{ "errorId" => 1001, "message" => "Invalid access token" }] },
          detailed_errors: [{ message: "Invalid access token", error_id: 1001 }]
        )
      end

      it 'creates EbayAuthenticationError with helpful message' do
        exception = client.send(:build_appropriate_exception, error_response)
        
        expect(exception).to be_a(EbayApiErrorHandling::EbayAuthenticationError)
        expect(exception.message).to eq("Invalid access token")
        expect(exception.status_code).to eq(401)
        expect(exception.detailed_errors).to be_present
      end
    end

    context 'when eBay returns 400 Bad Request' do
      let(:error_response) do
        EbayApiResponse.new(
          success: false,
          status_code: 400,
          error: { "errors" => [{ "errorId" => 25007, "message" => "Required field missing" }] },
          detailed_errors: [{ message: "Required field missing", error_id: 25007 }]
        )
      end

      it 'creates EbayValidationError with helpful message' do
        exception = client.send(:build_appropriate_exception, error_response)
        
        expect(exception).to be_a(EbayApiErrorHandling::EbayValidationError)
        expect(exception.message).to eq("Required field missing")
        expect(exception.status_code).to eq(400)
      end
    end

    context 'when eBay returns 429 Rate Limited' do
      let(:error_response) do
        EbayApiResponse.new(
          success: false,
          status_code: 429,
          error: { "errors" => [{ "errorId" => 1015, "message" => "Rate limit exceeded" }] },
          detailed_errors: [{ message: "Rate limit exceeded", error_id: 1015 }]
        )
      end

      it 'creates EbayRateLimitError' do
        exception = client.send(:build_appropriate_exception, error_response)
        
        expect(exception).to be_a(EbayApiErrorHandling::EbayRateLimitError)
        expect(exception.message).to eq("Rate limit exceeded")
        expect(exception.status_code).to eq(429)
      end
    end

    context 'when network error occurs' do
      let(:error_response) do
        EbayApiResponse.new(
          success: false,
          status_code: nil,
          error: "Connection timeout",
          detailed_errors: []
        )
      end

      it 'creates EbayNetworkError' do
        exception = client.send(:build_appropriate_exception, error_response)
        
        expect(exception).to be_a(EbayApiErrorHandling::EbayNetworkError)
        expect(exception.message).to eq("Connection timeout")
        expect(exception.status_code).to be_nil
      end
    end
  end

  describe 'Error Message Extraction' do
    it 'extracts message from detailed_errors when available' do
      response = EbayApiResponse.new(
        success: false,
        status_code: 400,
        error: { "errors" => [{ "errorId" => 25007 }] },
        detailed_errors: [{ message: "Detailed error message", long_message: "Even longer message" }]
      )

      message = client.send(:extract_user_friendly_message, response)
      expect(message).to eq("Detailed error message")
    end

    it 'falls back to long_message when message is missing' do
      response = EbayApiResponse.new(
        success: false,
        status_code: 400,
        error: { "errors" => [{ "errorId" => 25007 }] },
        detailed_errors: [{ long_message: "Long error message" }]
      )

      message = client.send(:extract_user_friendly_message, response)
      expect(message).to eq("Long error message")
    end

    it 'extracts message from hash error when detailed_errors not available' do
      response = EbayApiResponse.new(
        success: false,
        status_code: 400,
        error: { "message" => "Hash error message" },
        detailed_errors: []
      )

      message = client.send(:extract_user_friendly_message, response)
      expect(message).to eq("Hash error message")
    end

    it 'uses string error directly when hash not available' do
      response = EbayApiResponse.new(
        success: false,
        status_code: 400,
        error: "Simple string error",
        detailed_errors: []
      )

      message = client.send(:extract_user_friendly_message, response)
      expect(message).to eq("Simple string error")
    end

    it 'provides default message when no error info available' do
      response = EbayApiResponse.new(
        success: false,
        status_code: 500,
        error: nil,
        detailed_errors: []
      )

      message = client.send(:extract_user_friendly_message, response)
      expect(message).to eq("An error occurred with the eBay API")
    end
  end

  describe 'EbayApiResponse Format' do
    context 'when API call succeeds' do
      before do
        allow(client).to receive(:post).and_return(
          EbayApiResponse.new(
            success: true,
            status_code: 201,
            data: { "paymentPolicyId" => "12345", "name" => "Test Policy" }
          )
        )
      end

      it 'returns EbayApiResponse with correct format' do
        response = client.create_payment_policy(policy_data)
        
        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(201)
        expect(response.success?).to be true
        
        expect(response.data['paymentPolicyId']).to eq('12345')
        expect(response.data['name']).to eq('Test Policy')
      end
    end

    context 'when API call fails' do
      before do
        allow(client).to receive(:post).and_return(
          EbayApiResponse.new(
            success: false,
            status_code: 400,
            error: { "errors" => [{ "message" => "Invalid data" }] },
            detailed_errors: []
          )
        )
      end

      it 'returns EbayApiResponse error format' do
        response = client.create_fulfillment_policy(policy_data)
        
        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(400)
        expect(response.success?).to be false
        expect(response.error['errors']).to be_present
      end
    end

    context 'when unexpected exception occurs during API call' do
      before do
        allow(client).to receive(:post).and_raise(StandardError, "Connection failed")
      end

      it 'returns nil for legacy code compatibility' do
        response = client.create_return_policy(policy_data)
        expect(response).to be_nil
      end
    end
  end

  describe 'ApiResult Object' do
    context 'when operation succeeds' do
      let(:success_response) do
        EbayApiResponse.new(
          success: true,
          status_code: 201,
          data: { "id" => "12345", "name" => "Test Policy" }
        )
      end

      it 'creates successful ApiResult' do
        result = client.send(:handle_api_response, success_response)
        
        expect(result).to be_a(EbayApiErrorHandling::ApiResult)
        expect(result.success?).to be true
        expect(result.failure?).to be false
        expect(result.status_code).to eq(201)
        expect(result.data).to eq(success_response.data)
      end
    end

    context 'when operation fails' do
      let(:error_response) do
        EbayApiResponse.new(
          success: false,
          status_code: 400,
          error: { "message" => "Validation error" },
          detailed_errors: []
        )
      end

      it 'raises appropriate exception instead of creating failed result' do
        expect {
          client.send(:handle_api_response, error_response)
        }.to raise_error(EbayApiErrorHandling::EbayValidationError, "Validation error")
      end
    end
  end

  describe 'Integration Examples' do
    it 'enables clean controller error handling pattern' do
      # Simulate what a controller would do
      allow(client).to receive(:post).and_return(
        EbayApiResponse.new(
          success: false,
          status_code: 401,
          error: { "message" => "Token expired" },
          detailed_errors: []
        )
      )

      flash = {}
      
      begin
        # This would fail with current backward-compatible implementation
        # but demonstrates the intended usage pattern
        client.send(:handle_api_request_with_exceptions) do
          response = client.send(:post, "/sell/account/v1/payment_policy", policy_data)
          client.send(:handle_api_response, response)
        end
      rescue EbayApiErrorHandling::EbayAuthenticationError => e
        flash[:error] = "Please reconnect your eBay account"
      rescue EbayApiErrorHandling::EbayValidationError => e
        flash[:error] = "Invalid policy data: #{e.message}"
      rescue EbayApiErrorHandling::EbayApiError => e
        flash[:error] = "eBay error: #{e.message}"
      end

      expect(flash[:error]).to eq("Please reconnect your eBay account")
    end

    it 'provides detailed error information when needed' do
      error_response = EbayApiResponse.new(
        success: false,
        status_code: 400,
        error: { "errors" => [{ "errorId" => 25007, "message" => "Required field missing" }] },
        detailed_errors: [{ 
          message: "Required field missing: shippingOptions", 
          error_id: 25007,
          severity: "high"
        }]
      )

      exception = client.send(:build_appropriate_exception, error_response)
      
      expect(exception.message).to eq("Required field missing: shippingOptions")
      expect(exception.detailed_errors.first[:error_id]).to eq(25007)
      expect(exception.detailed_errors.first[:severity]).to eq("high")
    end
  end

  describe 'All Policy Methods Consistency' do
    let(:success_response) do
      EbayApiResponse.new(
        success: true,
        status_code: 201,
        data: { "id" => "12345", "name" => "Test Policy" }
      )
    end

    let(:methods_to_test) do
      [
        [:create_payment_policy, policy_data],
        [:update_payment_policy, "123", policy_data],
        [:create_return_policy, policy_data],
        [:update_return_policy, "123", policy_data],
        [:create_fulfillment_policy, policy_data],
        [:update_fulfillment_policy, "123", policy_data]
      ]
    end

    it 'all policy methods return consistent EbayApiResponse format' do
      methods_to_test.each do |method_name, *args|
        # Mock the underlying HTTP method to return success
        http_method = method_name.to_s.start_with?('create') ? :post : :put
        allow(client).to receive(http_method).and_return(success_response)

        response = client.public_send(method_name, *args)
        
        expect(response).to be_a(EbayApiResponse), "#{method_name} should return EbayApiResponse"
        expect(response.status_code).to eq(201), "#{method_name} should have correct status code"
        
        expect(response.success?).to be true
        expect(response.data).to have_key('id')
      end
    end
  end
end