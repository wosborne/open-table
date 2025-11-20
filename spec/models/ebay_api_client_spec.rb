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

      it 'returns EbayApiResponse with correct format' do
        response = client.create_fulfillment_policy(policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(201)
        expect(response.success?).to be true

        expect(response.data['fulfillmentPolicyId']).to eq('12345678')
        expect(response.data['name']).to eq('Test Fulfillment Policy')
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25001, "Required field missing") }

      before { stub_ebay_fulfillment_policy_creation(error_response) }

      it 'returns error response in correct format' do
        response = client.create_fulfillment_policy(policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(400)
        expect(response.success?).to be false

        expect(response.error['errors']).to be_present
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

      it 'returns EbayApiResponse with correct format' do
        response = client.create_payment_policy(policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(201)
        expect(response.success?).to be true

        expect(response.data['paymentPolicyId']).to eq('87654321')
        expect(response.data['name']).to eq('Test Payment Policy')
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25002, "Invalid payment method") }

      before { stub_ebay_payment_policy_creation(error_response) }

      it 'returns error response in correct format' do
        response = client.create_payment_policy(policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(400)
        expect(response.success?).to be false

        expect(response.error['errors']).to be_present
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

      it 'returns EbayApiResponse with correct format' do
        response = client.create_return_policy(policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(201)
        expect(response.success?).to be true

        expect(response.data['returnPolicyId']).to eq('11223344')
        expect(response.data['name']).to eq('Test Return Policy')
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25003, "Invalid return period") }

      before { stub_ebay_return_policy_creation(error_response) }

      it 'returns error response in correct format' do
        response = client.create_return_policy(policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(400)
        expect(response.success?).to be false

        expect(response.error['errors']).to be_present
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
        EbayApiResponse.new(
          success: false,
          status_code: 400,
          error: { "message" => "Validation failed" }
        )
      end

      before { stub_ebay_fulfillment_policy_creation(hash_error_response) }

      it 'converts hash error to JSON' do
        response = client.create_fulfillment_policy(policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(400)
        expect(response.success?).to be false
        expect(response.error['message']).to eq('Validation failed')
      end
    end

    context 'when error response has string error' do
      let(:string_error_response) do
        EbayApiResponse.new(
          success: false,
          status_code: 500,
          error: "Internal server error"
        )
      end

      before { stub_ebay_fulfillment_policy_creation(string_error_response) }

      it 'wraps string error in hash' do
        response = client.create_fulfillment_policy(policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(500)
        expect(response.success?).to be false
        expect(response.error).to eq('Internal server error')
      end
    end

    context 'when status code is missing' do
      let(:no_status_response) do
        EbayApiResponse.new(
          success: false,
          status_code: nil,
          error: "Unknown error"
        )
      end

      before { stub_ebay_fulfillment_policy_creation(no_status_response) }

      it 'handles missing status code' do
        response = client.create_fulfillment_policy(policy_data)
        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to be_nil
        expect(response.success?).to be false
        expect(response.error).to eq('Unknown error')
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
        expect(response).to be_a(EbayApiResponse)
      end
    end
  end

  describe 'JSON parsing edge cases' do
    let(:policy_data) { { name: "Test Policy" } }

    context 'when response contains special characters' do
      let(:special_char_response) do
        EbayApiResponse.new(
          success: true,
          status_code: 201,
          data: {
            "fulfillmentPolicyId" => "12345678",
            "name" => "Policy with émojis 🚀 and spéçial chars"
          }
        )
      end

      before { stub_ebay_fulfillment_policy_creation(special_char_response) }

      it 'handles UTF-8 characters correctly' do
        response = client.create_fulfillment_policy(policy_data)
        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(201)
        expect(response.success?).to be true
        expect(response.data['name']).to eq("Policy with émojis 🚀 and spéçial chars")
      end
    end
  end

  describe '#get_fulfillment_policies' do
    context 'when API call succeeds' do
      before do
        allow(client).to receive(:get)
          .with("/sell/account/v1/fulfillment_policy", { marketplace_id: "EBAY_GB" })
          .and_return(mock_fulfillment_policies_response)
      end

      it 'makes GET request to correct endpoint' do
        expect(client).to receive(:get).with("/sell/account/v1/fulfillment_policy", { marketplace_id: "EBAY_GB" })
        client.get_fulfillment_policies
      end

      it 'returns response with fulfillment policies' do
        response = client.get_fulfillment_policies
        expect(response.success?).to be true
        expect(response.data['fulfillmentPolicies']).to be_an(Array)
        expect(response.data['fulfillmentPolicies'].size).to eq(2)
      end
    end
  end

  describe '#get_payment_policies' do
    context 'when API call succeeds' do
      before do
        allow(client).to receive(:get)
          .with("/sell/account/v1/payment_policy", { marketplace_id: "EBAY_GB" })
          .and_return(mock_payment_policies_response)
      end

      it 'makes GET request to correct endpoint' do
        expect(client).to receive(:get).with("/sell/account/v1/payment_policy", { marketplace_id: "EBAY_GB" })
        client.get_payment_policies
      end

      it 'returns response with payment policies' do
        response = client.get_payment_policies
        expect(response.success?).to be true
        expect(response.data['paymentPolicies']).to be_an(Array)
        expect(response.data['paymentPolicies'].size).to eq(2)
      end
    end
  end

  describe '#get_return_policies' do
    context 'when API call succeeds' do
      before do
        allow(client).to receive(:get)
          .with("/sell/account/v1/return_policy", { marketplace_id: "EBAY_GB" })
          .and_return(mock_return_policies_response)
      end

      it 'makes GET request to correct endpoint' do
        expect(client).to receive(:get).with("/sell/account/v1/return_policy", { marketplace_id: "EBAY_GB" })
        client.get_return_policies
      end

      it 'returns response with return policies' do
        response = client.get_return_policies
        expect(response.success?).to be true
        expect(response.data['returnPolicies']).to be_an(Array)
        expect(response.data['returnPolicies'].size).to eq(2)
      end
    end
  end

  describe '#update_fulfillment_policy' do
    let(:policy_id) { '12345678' }
    let(:policy_data) do
      {
        name: "Updated Fulfillment Policy",
        marketplaceId: "EBAY_GB",
        handlingTime: { value: 2, unit: "DAY" }
      }
    end

    context 'when API call succeeds' do
      before { stub_ebay_fulfillment_policy_update(policy_id) }

      it 'makes PUT request to correct endpoint' do
        expect(client).to receive(:put).with("/sell/account/v1/fulfillment_policy/#{policy_id}", policy_data)
        client.update_fulfillment_policy(policy_id, policy_data)
      end

      it 'returns EbayApiResponse with correct format' do
        response = client.update_fulfillment_policy(policy_id, policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(200)
        expect(response.success?).to be true

        expect(response.data['fulfillmentPolicyId']).to eq('12345678')
        expect(response.data['name']).to eq('Updated Fulfillment Policy')
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25001, "Policy not found") }

      before { stub_ebay_fulfillment_policy_update(policy_id, error_response) }

      it 'returns error response in correct format' do
        response = client.update_fulfillment_policy(policy_id, policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(400)
        expect(response.success?).to be false

        expect(response.error['errors']).to be_present
      end
    end

    context 'when exception occurs' do
      before do
        allow(client).to receive(:put).and_raise(StandardError, "Network timeout")
      end

      it 'handles exception gracefully' do
        expect(Rails.logger).to receive(:error).with(match(/Unexpected error updating fulfillment policy/))
        response = client.update_fulfillment_policy(policy_id, policy_data)
        expect(response).to be_nil
      end
    end
  end

  describe '#update_payment_policy' do
    let(:policy_id) { '87654321' }
    let(:policy_data) do
      {
        name: "Updated Payment Policy",
        marketplaceId: "EBAY_GB",
        immediatePay: false
      }
    end

    context 'when API call succeeds' do
      before { stub_ebay_payment_policy_update(policy_id) }

      it 'makes PUT request to correct endpoint' do
        expect(client).to receive(:put).with("/sell/account/v1/payment_policy/#{policy_id}", policy_data)
        client.update_payment_policy(policy_id, policy_data)
      end

      it 'returns EbayApiResponse with correct format' do
        response = client.update_payment_policy(policy_id, policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(200)
        expect(response.success?).to be true

        expect(response.data['paymentPolicyId']).to eq('87654321')
        expect(response.data['name']).to eq('Updated Payment Policy')
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25002, "Invalid payment method") }

      before { stub_ebay_payment_policy_update(policy_id, error_response) }

      it 'returns error response in correct format' do
        response = client.update_payment_policy(policy_id, policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(400)
        expect(response.success?).to be false

        expect(response.error['errors']).to be_present
      end
    end

    context 'when exception occurs' do
      before do
        allow(client).to receive(:put).and_raise(StandardError, "Connection failed")
      end

      it 'handles exception gracefully' do
        expect(Rails.logger).to receive(:error).with(match(/Unexpected error updating payment policy/))
        response = client.update_payment_policy(policy_id, policy_data)
        expect(response).to be_nil
      end
    end
  end

  describe '#update_return_policy' do
    let(:policy_id) { '11223344' }
    let(:policy_data) do
      {
        name: "Updated Return Policy",
        marketplaceId: "EBAY_GB",
        returnsAccepted: false
      }
    end

    context 'when API call succeeds' do
      before { stub_ebay_return_policy_update(policy_id) }

      it 'makes PUT request to correct endpoint' do
        expect(client).to receive(:put).with("/sell/account/v1/return_policy/#{policy_id}", policy_data)
        client.update_return_policy(policy_id, policy_data)
      end

      it 'returns EbayApiResponse with correct format' do
        response = client.update_return_policy(policy_id, policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(200)
        expect(response.success?).to be true

        expect(response.data['returnPolicyId']).to eq('11223344')
        expect(response.data['name']).to eq('Updated Return Policy')
      end
    end

    context 'when API call fails' do
      let(:error_response) { mock_api_error_response(25003, "Invalid return period") }

      before { stub_ebay_return_policy_update(policy_id, error_response) }

      it 'returns error response in correct format' do
        response = client.update_return_policy(policy_id, policy_data)

        expect(response).to be_a(EbayApiResponse)
        expect(response.status_code).to eq(400)
        expect(response.success?).to be false

        expect(response.error['errors']).to be_present
      end
    end

    context 'when exception occurs' do
      before do
        allow(client).to receive(:put).and_raise(StandardError, "Timeout error")
      end

      it 'handles exception gracefully' do
        expect(Rails.logger).to receive(:error).with(match(/Unexpected error updating return policy/))
        response = client.update_return_policy(policy_id, policy_data)
        expect(response).to be_nil
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
