require 'rails_helper'

RSpec.describe ExternalAccount, type: :model do
  include EbayApiMocking

  let(:account) { create(:account) }
  let(:external_account) { create(:external_account, :ebay, account: account) }

  before do
    mock_ebay_api_responses

    # Mock all Rails credentials to prevent unexpected calls
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :api_base_url).and_return('https://api.ebay.com')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return('test_client_id')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return('test_client_secret')
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :token_url).and_return('https://api.ebay.com/identity/v1/oauth2/token')

    # Mock the logger to prevent overly strict expectations
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)

    # Mock location sync to prevent side effects
    allow_any_instance_of(ExternalAccount).to receive(:sync_ebay_inventory_locations).and_return(true)
  end

  describe '#sync_ebay_business_policies' do
    context 'when external account is eBay' do
      before { stub_ebay_policy_fetching }

      it 'calls all policy sync methods' do
        expect(external_account).to receive(:sync_fulfillment_policies)
        expect(external_account).to receive(:sync_payment_policies)
        expect(external_account).to receive(:sync_return_policies)

        external_account.sync_ebay_business_policies
      end

      it 'logs error if exception occurs' do
        allow(external_account).to receive(:sync_fulfillment_policies).and_raise(StandardError, "API Error")
        expect(Rails.logger).to receive(:error).with(match(/Error synchronizing eBay business policies: API Error/))

        external_account.sync_ebay_business_policies
      end
    end

    context 'when external account is not eBay' do
      let(:shopify_account) { create(:external_account, account: account) }

      it 'does not sync policies' do
        expect(shopify_account).not_to receive(:sync_fulfillment_policies)
        shopify_account.sync_ebay_business_policies
      end
    end
  end

  describe '#sync_fulfillment_policies' do
    let(:ebay_client) { instance_double(EbayApiClient) }

    before do
      allow(EbayApiClient).to receive(:new).with(external_account).and_return(ebay_client)
    end

    context 'when API call succeeds' do
      before do
        allow(ebay_client).to receive(:get_fulfillment_policies).and_return(mock_fulfillment_policies_response)
        allow(ebay_client).to receive(:get_fulfillment_policy).and_return(mock_individual_policy_response)
      end

      it 'creates new policies that do not exist locally' do
        expect {
          external_account.send(:sync_fulfillment_policies)
        }.to change { external_account.fulfillment_policies.count }.by(2)

        policy1 = external_account.fulfillment_policies.find_by(ebay_policy_id: '123456789')
        expect(policy1.name).to eq('Standard Fulfillment')
        expect(policy1.marketplace_id).to eq('EBAY_GB')

        policy2 = external_account.fulfillment_policies.find_by(ebay_policy_id: '987654321')
        expect(policy2.name).to eq('Express Fulfillment')
        expect(policy2.marketplace_id).to eq('EBAY_GB')
      end

      it 'does not create duplicate policies' do
        # Create existing policy
        external_account.fulfillment_policies.create!(
          ebay_policy_id: '123456789',
          name: 'Existing Policy',
          marketplace_id: 'EBAY_GB'
        )

        expect {
          external_account.send(:sync_fulfillment_policies)
        }.to change { external_account.fulfillment_policies.count }.by(1) # Only one new policy

        expect(external_account.fulfillment_policies.where(ebay_policy_id: '123456789').count).to eq(1)
      end

      it 'handles policies with missing marketplace_id' do
        response_with_missing_marketplace = EbayApiResponse.new(
          success: true,
          status_code: 200,
          data: {
            "fulfillmentPolicies" => [
              {
                "fulfillmentPolicyId" => "555555555",
                "name" => "Policy Without Marketplace"
              }
            ]
          }
        )
        allow(ebay_client).to receive(:get_fulfillment_policies).and_return(response_with_missing_marketplace)

        expect {
          external_account.send(:sync_fulfillment_policies)
        }.to change { external_account.fulfillment_policies.count }.by(1)

        policy = external_account.fulfillment_policies.find_by(ebay_policy_id: '555555555')
        expect(policy.marketplace_id).to eq('EBAY_GB') # Defaults to EBAY_GB
      end
    end

    context 'when API call fails' do
      before do
        allow(ebay_client).to receive(:get_fulfillment_policies).and_return(mock_policy_api_error)
      end

      it 'logs error and does not create policies' do
        expect(Rails.logger).to receive(:error).with(match(/Failed to fetch eBay fulfillment policies/))

        expect {
          external_account.send(:sync_fulfillment_policies)
        }.not_to change { external_account.fulfillment_policies.count }
      end
    end

    context 'when response has empty policies' do
      before do
        allow(ebay_client).to receive(:get_fulfillment_policies).and_return(mock_empty_policies_response)
      end

      it 'does not create any policies' do
        expect {
          external_account.send(:sync_fulfillment_policies)
        }.not_to change { external_account.fulfillment_policies.count }
      end
    end
  end

  describe '#sync_payment_policies' do
    let(:ebay_client) { instance_double(EbayApiClient) }

    before do
      allow(EbayApiClient).to receive(:new).with(external_account).and_return(ebay_client)
      allow(ebay_client).to receive(:get_payment_policies).and_return(mock_payment_policies_response)
      allow(ebay_client).to receive(:get_payment_policy).and_return(mock_individual_policy_response)
    end

    it 'creates payment policies with correct attributes' do
      expect {
        external_account.send(:sync_payment_policies)
      }.to change { external_account.payment_policies.count }.by(2)

      policy = external_account.payment_policies.find_by(ebay_policy_id: '111111111')
      expect(policy.policy_type).to eq('payment')
      expect(policy.name).to eq('PayPal Payment')
    end
  end

  describe '#sync_return_policies' do
    let(:ebay_client) { instance_double(EbayApiClient) }

    before do
      allow(EbayApiClient).to receive(:new).with(external_account).and_return(ebay_client)
      allow(ebay_client).to receive(:get_return_policies).and_return(mock_return_policies_response)
      allow(ebay_client).to receive(:get_return_policy).and_return(mock_individual_policy_response)
    end

    it 'creates return policies with correct attributes' do
      expect {
        external_account.send(:sync_return_policies)
      }.to change { external_account.return_policies.count }.by(2)

      policy = external_account.return_policies.find_by(ebay_policy_id: '333333333')
      expect(policy.policy_type).to eq('return')
      expect(policy.name).to eq('30 Day Returns')
    end
  end

  describe 'policy creation callback' do
    context 'when creating eBay external account' do
      before do
        stub_ebay_policy_fetching
        # Prevent location sync from interfering with tests
        allow_any_instance_of(ExternalAccount).to receive(:sync_ebay_inventory_locations)
      end

      it 'automatically syncs business policies' do
        expect_any_instance_of(ExternalAccount).to receive(:sync_ebay_business_policies)
        create(:external_account, :ebay, account: account)
      end
    end

    context 'when creating Shopify external account' do
      it 'does not sync business policies' do
        expect_any_instance_of(ExternalAccount).not_to receive(:sync_ebay_business_policies)
        create(:external_account, account: account)
      end
    end
  end

  describe 'error handling in policy creation' do
    let(:ebay_client) { instance_double(EbayApiClient) }

    before do
      allow(EbayApiClient).to receive(:new).with(external_account).and_return(ebay_client)
      allow(ebay_client).to receive(:get_fulfillment_policies).and_return(mock_fulfillment_policies_response)
    end

    it 'logs validation errors when policy creation fails' do
      # Mock validation failure by making the policy creation fail
      allow_any_instance_of(EbayBusinessPolicy).to receive(:save).and_return(false)
      allow_any_instance_of(EbayBusinessPolicy).to receive(:errors).and_return(double(full_messages: [ 'Name cannot be blank' ]))

      expect(Rails.logger).to receive(:error).with(match(/Failed to create fulfillment policy.*Name cannot be blank/))

      external_account.send(:sync_fulfillment_policies)
    end
  end

  describe 'private helper methods' do
    describe '#policy_exists_locally?' do
      it 'returns true when policy exists' do
        EbayFulfillmentPolicy.create!(
          external_account: external_account,
          ebay_policy_id: '123456789',
          name: 'Test Policy',
          marketplace_id: 'EBAY_GB'
        )

        expect(external_account.send(:policy_exists_locally?, '123456789')).to be true
      end

      it 'returns false when policy does not exist' do
        expect(external_account.send(:policy_exists_locally?, 'nonexistent')).to be false
      end
    end

    describe '#create_policy_from_ebay_data' do
      it 'creates fulfillment policy with correct attributes' do
        policy_data = {
          'fulfillmentPolicyId' => '999999999',
          'name' => 'Test Fulfillment',
          'marketplaceId' => 'EBAY_US'
        }

        expect {
          external_account.send(:create_policy_from_ebay_data, 'fulfillment', policy_data)
        }.to change { external_account.fulfillment_policies.count }.by(1)

        policy = external_account.fulfillment_policies.last
        expect(policy.ebay_policy_id).to eq('999999999')
        expect(policy.name).to eq('Test Fulfillment')
        expect(policy.marketplace_id).to eq('EBAY_US')
      end

      it 'creates payment policy with correct ID field' do
        policy_data = {
          'paymentPolicyId' => '888888888',
          'name' => 'Test Payment'
        }

        external_account.send(:create_policy_from_ebay_data, 'payment', policy_data)

        policy = external_account.payment_policies.last
        expect(policy.ebay_policy_id).to eq('888888888')
      end

      it 'creates return policy with correct ID field' do
        policy_data = {
          'returnPolicyId' => '777777777',
          'name' => 'Test Return'
        }

        external_account.send(:create_policy_from_ebay_data, 'return', policy_data)

        policy = external_account.return_policies.last
        expect(policy.ebay_policy_id).to eq('777777777')
      end
    end
  end
end
