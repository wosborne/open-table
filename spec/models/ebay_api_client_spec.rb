require 'rails_helper'

RSpec.describe EbayApiClient, type: :model do
  include EbayApiMocking

  let(:external_account) { create(:external_account, :ebay) }
  let(:client) { described_class.new(external_account) }

  before do
    mock_ebay_api_responses

    # Mock all Rails credentials to prevent unexpected calls
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :api_base_url).and_return('https://api.ebay.com')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return('test_client_id')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return('test_client_secret')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :token_url).and_return('https://api.ebay.com/identity/v1/oauth2/token')
    allow(Rails.application.credentials).to receive(:dig).with(:aws, :access_key_id).and_return('test_aws_key')
    allow(Rails.application.credentials).to receive(:dig).with(:aws, :secret_access_key).and_return('test_aws_secret')
    allow(Rails.application.credentials).to receive(:dig).with(:aws, :region).and_return('us-east-1')

    # Mock external account operations to prevent real API calls
    allow_any_instance_of(ExternalAccount).to receive(:sync_ebay_inventory_locations).and_return(true)
    allow_any_instance_of(ExternalAccount).to receive(:fetch_ebay_inventory_locations).and_return([])

    # Mock the logger to prevent overly strict expectations
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#initialize' do
    it 'sets up client with external account' do
      expect(client.external_account).to eq(external_account)
      expect(client.access_token).to eq(external_account.api_token)
      expect(client.api_base_url).to eq('https://api.ebay.com')
    end
  end

  describe '#create_fulfillment_policy' do
    let(:policy_data) do
      {
        name: "Test Fulfillment Policy",
        marketplaceId: "EBAY_GB",
        categoryTypes: [ { name: "ALL_EXCLUDING_MOTORS_VEHICLES", default: true } ],
        handlingTime: { value: 1, unit: "DAY" },
        shippingOptions: [
          {
            costType: "FLAT_RATE",
            shippingServices: [
              {
                shippingServiceCode: "UK_RoyalMailFirstClassStandard",
                freeShipping: false,
                shippingCost: { value: "2.50", currency: "GBP" }
              }
            ]
          }
        ]
      }
    end

    context 'when API call succeeds' do
      before { stub_ebay_fulfillment_policy_creation }

      it 'makes POST request to correct endpoint' do
        expect(client).to receive(:post).with("/sell/account/v1/fulfillment_policy", policy_data)
        client.create_fulfillment_policy(policy_data)
      end

      it 'returns OpenStruct response with correct format' do
        response = client.create_fulfillment_policy(policy_data)

        expect(response).to be_a(OpenStruct)
        expect(response.code).to eq(201)

        body_data = JSON.parse(response.body)
        expect(body_data['fulfillmentPolicyId']).to eq('12345678')
        expect(body_data['name']).to eq('Test Fulfillment Policy')
      end

      it 'logs successful creation' do
        expect(Rails.logger).to receive(:info).with(match(/Creating fulfillment policy/))
        expect(Rails.logger).to receive(:info).with(match(/Create fulfillment policy response: 201/))
        client.create_fulfillment_policy(policy_data)
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25001, "Required field missing") }

      before { stub_ebay_fulfillment_policy_creation(error_response) }

      it 'returns error response in correct format' do
        response = client.create_fulfillment_policy(policy_data)

        expect(response).to be_a(OpenStruct)
        expect(response.code).to eq(400)

        body_data = JSON.parse(response.body)
        expect(body_data['errors']).to be_present
      end

      it 'logs error details' do
        expect(Rails.logger).to receive(:error).with(match(/eBay fulfillment policy creation error/))
        client.create_fulfillment_policy(policy_data)
      end
    end

    context 'when network error occurs' do
      before do
        allow(client).to receive(:post).and_raise(StandardError, "Network timeout")
      end

      it 'handles exception gracefully' do
        expect(Rails.logger).to receive(:error).with(match(/Unexpected error creating fulfillment policy/))
        response = client.create_fulfillment_policy(policy_data)
        expect(response).to be_nil
      end
    end
  end

  describe '#create_payment_policy' do
    let(:policy_data) do
      {
        name: "Test Payment Policy",
        marketplaceId: "EBAY_GB",
        categoryTypes: [ { name: "ALL_EXCLUDING_MOTORS_VEHICLES", default: true } ],
        paymentMethods: [
          {
            paymentMethodType: "PAYPAL",
            recipientAccountReference: {
              referenceId: "test@example.com",
              referenceType: "PAYPAL_EMAIL"
            }
          }
        ],
        immediatePay: true
      }
    end

    context 'when API call succeeds' do
      before { stub_ebay_payment_policy_creation }

      it 'makes POST request to correct endpoint' do
        expect(client).to receive(:post).with("/sell/account/v1/payment_policy", policy_data)
        client.create_payment_policy(policy_data)
      end

      it 'returns OpenStruct response with correct format' do
        response = client.create_payment_policy(policy_data)

        expect(response).to be_a(OpenStruct)
        expect(response.code).to eq(201)

        body_data = JSON.parse(response.body)
        expect(body_data['paymentPolicyId']).to eq('87654321')
        expect(body_data['name']).to eq('Test Payment Policy')
      end

      it 'logs successful creation' do
        expect(Rails.logger).to receive(:info).with(match(/Creating payment policy/))
        expect(Rails.logger).to receive(:info).with(match(/Create payment policy response: 201/))
        client.create_payment_policy(policy_data)
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25002, "Invalid payment method") }

      before { stub_ebay_payment_policy_creation(error_response) }

      it 'returns error response in correct format' do
        response = client.create_payment_policy(policy_data)

        expect(response).to be_a(OpenStruct)
        expect(response.code).to eq(400)

        body_data = JSON.parse(response.body)
        expect(body_data['errors']).to be_present
      end

      it 'logs error details' do
        expect(Rails.logger).to receive(:error).with(match(/eBay payment policy creation error/))
        client.create_payment_policy(policy_data)
      end
    end

    context 'when exception occurs' do
      before do
        allow(client).to receive(:post).and_raise(StandardError, "Connection failed")
      end

      it 'handles exception gracefully' do
        expect(Rails.logger).to receive(:error).with(match(/Unexpected error creating payment policy/))
        response = client.create_payment_policy(policy_data)
        expect(response).to be_nil
      end
    end
  end

  describe '#create_return_policy' do
    let(:policy_data) do
      {
        name: "Test Return Policy",
        marketplaceId: "EBAY_GB",
        categoryTypes: [ { name: "ALL_EXCLUDING_MOTORS_VEHICLES", default: true } ],
        returnsAccepted: true,
        returnPeriod: { value: 30, unit: "DAY" },
        returnShippingCostPayer: "BUYER",
        returnMethod: "REPLACEMENT"
      }
    end

    context 'when API call succeeds' do
      before { stub_ebay_return_policy_creation }

      it 'makes POST request to correct endpoint' do
        expect(client).to receive(:post).with("/sell/account/v1/return_policy", policy_data)
        client.create_return_policy(policy_data)
      end

      it 'returns OpenStruct response with correct format' do
        response = client.create_return_policy(policy_data)

        expect(response).to be_a(OpenStruct)
        expect(response.code).to eq(201)

        body_data = JSON.parse(response.body)
        expect(body_data['returnPolicyId']).to eq('11223344')
        expect(body_data['name']).to eq('Test Return Policy')
      end

      it 'logs successful creation' do
        expect(Rails.logger).to receive(:info).with(match(/Creating return policy/))
        expect(Rails.logger).to receive(:info).with(match(/Create return policy response: 201/))
        client.create_return_policy(policy_data)
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25003, "Invalid return period") }

      before { stub_ebay_return_policy_creation(error_response) }

      it 'returns error response in correct format' do
        response = client.create_return_policy(policy_data)

        expect(response).to be_a(OpenStruct)
        expect(response.code).to eq(400)

        body_data = JSON.parse(response.body)
        expect(body_data['errors']).to be_present
      end

      it 'logs error details' do
        expect(Rails.logger).to receive(:error).with(match(/eBay return policy creation error/))
        client.create_return_policy(policy_data)
      end
    end

    context 'when exception occurs' do
      before do
        allow(client).to receive(:post).and_raise(StandardError, "Timeout error")
      end

      it 'handles exception gracefully' do
        expect(Rails.logger).to receive(:error).with(match(/Unexpected error creating return policy/))
        response = client.create_return_policy(policy_data)
        expect(response).to be_nil
      end
    end
  end

  describe 'error response handling' do
    let(:policy_data) { { name: "Test Policy" } }

    context 'when error response has hash error' do
      let(:hash_error_response) do
        {
          success: false,
          status_code: 400,
          error: { "message" => "Validation failed" }
        }
      end

      before { stub_ebay_fulfillment_policy_creation(hash_error_response) }

      it 'converts hash error to JSON' do
        response = client.create_fulfillment_policy(policy_data)

        expect(response.code).to eq(400)
        body_data = JSON.parse(response.body)
        expect(body_data['message']).to eq('Validation failed')
      end
    end

    context 'when error response has string error' do
      let(:string_error_response) do
        {
          success: false,
          status_code: 500,
          error: "Internal server error"
        }
      end

      before { stub_ebay_fulfillment_policy_creation(string_error_response) }

      it 'wraps string error in hash' do
        response = client.create_fulfillment_policy(policy_data)

        expect(response.code).to eq(500)
        body_data = JSON.parse(response.body)
        expect(body_data['error']).to eq('Internal server error')
      end
    end

    context 'when status code is missing' do
      let(:no_status_response) do
        {
          success: false,
          error: "Unknown error"
        }
      end

      before { stub_ebay_fulfillment_policy_creation(no_status_response) }

      it 'defaults to 500 status code' do
        response = client.create_fulfillment_policy(policy_data)
        expect(response.code).to eq(500)
      end
    end
  end

  describe 'authentication and token refresh' do
    let(:policy_data) { { name: "Test Policy" } }

    context 'when token needs refresh' do
      let(:auth_error) { mock_auth_error_response }

      before do
        allow(client).to receive(:post).and_return(auth_error).once
        allow(client).to receive(:post).and_return(mock_successful_fulfillment_policy_creation)
        allow(client).to receive(:refresh_access_token).and_return(true)
      end

      it 'handles token refresh in underlying make_request method' do
        response = client.create_fulfillment_policy(policy_data)
        expect(response).to be_a(OpenStruct)
      end
    end
  end

  describe 'JSON parsing edge cases' do
    let(:policy_data) { { name: "Test Policy" } }

    context 'when response contains special characters' do
      let(:special_char_response) do
        {
          success: true,
          status_code: 201,
          data: {
            "fulfillmentPolicyId" => "12345678",
            "name" => "Policy with émojis 🚀 and spéçial chars"
          }
        }
      end

      before { stub_ebay_fulfillment_policy_creation(special_char_response) }

      it 'handles UTF-8 characters correctly' do
        response = client.create_fulfillment_policy(policy_data)
        body_data = JSON.parse(response.body)
        expect(body_data['name']).to eq("Policy with émojis 🚀 and spéçial chars")
      end
    end
  end

  describe 'integration with base HTTP methods' do
    it 'uses POST method for policy creation' do
      expect(client).to respond_to(:post)
      expect(client).to respond_to(:get)
      expect(client).to respond_to(:put)
      expect(client).to respond_to(:delete)
    end

    it 'creates client with correct instance variables' do
      expect(client.instance_variable_get(:@external_account)).to eq(external_account)
      expect(client.instance_variable_get(:@access_token)).to eq(external_account.api_token)
      expect(client.instance_variable_get(:@api_base_url)).to eq('https://api.ebay.com')
    end
  end
end
