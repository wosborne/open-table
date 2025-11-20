require 'rails_helper'

RSpec.describe EbayBusinessPolicy, type: :model do
  include EbayApiMocking

  let(:external_account) { create(:external_account, :ebay) }

  before do
    mock_ebay_api_responses
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe 'associations' do
    it 'belongs to external account' do
      policy = build(:ebay_business_policy, external_account: external_account)
      expect(policy.external_account).to eq(external_account)
    end
  end

  describe 'validations' do
    let(:valid_attributes) do
      {
        external_account: external_account,
        type: 'EbayFulfillmentPolicy',
        ebay_policy_id: '12345678',
        name: 'Test Policy',
        marketplace_id: 'EBAY_GB'
      }
    end

    it 'does not require ebay_policy_id for new records' do
      policy = build(:ebay_business_policy, valid_attributes.merge(ebay_policy_id: nil))
      policy.valid?
      expect(policy.errors[:ebay_policy_id]).to be_empty
    end

    it 'requires ebay_policy_id for persisted records' do
      policy = create(:ebay_business_policy, valid_attributes)
      policy.ebay_policy_id = nil
      expect(policy).not_to be_valid
      expect(policy.errors[:ebay_policy_id]).to include("can't be blank")
    end

    it 'validates presence of name' do
      policy = build(:ebay_business_policy, valid_attributes.merge(name: nil))
      expect(policy).not_to be_valid
      expect(policy.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of marketplace_id' do
      policy = build(:ebay_business_policy, valid_attributes.merge(marketplace_id: nil))
      expect(policy).not_to be_valid
      expect(policy.errors[:marketplace_id]).to include("can't be blank")
    end


    it 'has uniqueness validation for ebay_policy_id' do
      expect(described_class.validators_on(:ebay_policy_id).map(&:class)).to include(ActiveRecord::Validations::UniquenessValidator)
    end

    it 'is valid with valid attributes' do
      policy = build(:ebay_business_policy, valid_attributes)
      expect(policy).to be_valid
    end
  end

  describe 'scopes' do
    let!(:fulfillment_policy) { create(:ebay_fulfillment_policy, external_account: external_account) }
    let!(:payment_policy) { create(:ebay_payment_policy, external_account: external_account) }
    let!(:return_policy) { create(:ebay_return_policy, external_account: external_account) }

    describe '.fulfillment' do
      it 'returns only fulfillment policies' do
        expect(described_class.fulfillment).to contain_exactly(fulfillment_policy)
      end
    end

    describe '.payment' do
      it 'returns only payment policies' do
        expect(described_class.payment).to contain_exactly(payment_policy)
      end
    end

    describe '.return' do
      it 'returns only return policies' do
        expect(described_class.return).to contain_exactly(return_policy)
      end
    end
  end

  describe 'instance methods' do
    describe '#fulfillment?' do
      it 'returns true for fulfillment policy' do
        policy = build(:ebay_fulfillment_policy)
        expect(policy.fulfillment?).to be true
      end

      it 'returns false for non-fulfillment policy' do
        policy = build(:ebay_payment_policy)
        expect(policy.fulfillment?).to be false
      end
    end

    describe '#payment?' do
      it 'returns true for payment policy' do
        policy = build(:ebay_payment_policy)
        expect(policy.payment?).to be true
      end

      it 'returns false for non-payment policy' do
        policy = build(:ebay_fulfillment_policy)
        expect(policy.payment?).to be false
      end
    end

    describe '#return?' do
      it 'returns true for return policy' do
        policy = build(:ebay_return_policy)
        expect(policy.return?).to be true
      end

      it 'returns false for non-return policy' do
        policy = build(:ebay_payment_policy)
        expect(policy.return?).to be false
      end
    end
  end

  describe 'factory' do
    it 'creates valid ebay business policy' do
      policy = build(:ebay_business_policy, external_account: external_account)
      expect(policy).to be_valid
    end

    it 'creates fulfillment policy' do
      policy = build(:ebay_fulfillment_policy, external_account: external_account)
      expect(policy.policy_type).to eq 'fulfillment'
      expect(policy.fulfillment?).to be true
    end

    it 'creates payment policy' do
      policy = build(:ebay_payment_policy, external_account: external_account)
      expect(policy.policy_type).to eq 'payment'
      expect(policy.payment?).to be true
    end

    it 'creates return policy' do
      policy = build(:ebay_return_policy, external_account: external_account)
      expect(policy.policy_type).to eq 'return'
      expect(policy.return?).to be true
    end
  end

  describe 'validation edge cases' do
    let(:valid_attributes) do
      {
        external_account: external_account,
        type: 'EbayFulfillmentPolicy',
        ebay_policy_id: '12345678',
        name: 'Test Policy',
        marketplace_id: 'EBAY_GB'
      }
    end

    it 'is invalid without external account' do
      policy = build(:ebay_business_policy, valid_attributes.merge(external_account: nil))
      expect(policy).not_to be_valid
      expect(policy.errors[:external_account]).to include('must exist')
    end

    it 'is invalid with empty string values' do
      policy = build(:ebay_business_policy,
        valid_attributes.merge(
          name: '',
          marketplace_id: ''
        )
      )

      expect(policy).not_to be_valid
      expect(policy.errors[:name]).to include("can't be blank")
      expect(policy.errors[:marketplace_id]).to include("can't be blank")
    end
  end


  describe 'database constraints' do
    it 'enforces uniqueness at database level' do
      create(:ebay_business_policy, ebay_policy_id: '12345', external_account: external_account)

      expect {
        EbayPaymentPolicy.create!(
          ebay_policy_id: '12345',
          external_account: external_account,
          name: 'Test',
          marketplace_id: 'EBAY_GB'
        )
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'eBay API integration callbacks' do
    let(:policy_data) do
      {
        name: "Test Policy",
        marketplaceId: "EBAY_GB",
        categoryTypes: [ { name: "ALL_EXCLUDING_MOTORS_VEHICLES", default: true } ]
      }
    end

    describe 'before_create callback' do
      context 'when eBay API call succeeds' do
        let(:success_response) do
          response = EbayApiResponse.new(
            success: true,
            status_code: 201,
            data: { 'fulfillmentPolicyId' => '12345678' }
          )
          allow(response).to receive(:body).and_return('{"fulfillmentPolicyId":"12345678"}')
          response
        end

        before do
          allow_any_instance_of(EbayApiClient).to receive(:create_fulfillment_policy)
            .and_return(success_response)
        end

        it 'creates fulfillment policy on eBay and sets ebay_policy_id' do
          policy = build(:ebay_fulfillment_policy,
            external_account: external_account,
            ebay_policy_id: nil
          )
          policy.ebay_policy_data = policy_data

          expect(policy.save).to be true
          expect(policy.ebay_policy_id).to eq('12345678')
        end


        it 'works for payment policies' do
          payment_response = EbayApiResponse.new(
            success: true,
            status_code: 201,
            data: { 'paymentPolicyId' => '87654321' }
          )

          allow_any_instance_of(EbayApiClient).to receive(:create_payment_policy)
            .and_return(payment_response)

          policy = build(:ebay_payment_policy,
            external_account: external_account,
            ebay_policy_id: nil
          )
          policy.ebay_policy_data = policy_data

          expect(policy.save).to be true
          expect(policy.ebay_policy_id).to eq('87654321')
        end

        it 'works for return policies' do
          return_response = EbayApiResponse.new(
            success: true,
            status_code: 201,
            data: { 'returnPolicyId' => '11223344' }
          )

          allow_any_instance_of(EbayApiClient).to receive(:create_return_policy)
            .and_return(return_response)

          policy = build(:ebay_return_policy,
            external_account: external_account,
            ebay_policy_id: nil
          )
          policy.ebay_policy_data = policy_data

          expect(policy.save).to be true
          expect(policy.ebay_policy_id).to eq('11223344')
        end
      end

      context 'when eBay API call fails' do
        let(:error_response) do
          response = EbayApiResponse.new(
            success: false,
            status_code: 400,
            error: { 'errors' => [ { 'errorId' => 25007, 'message' => 'Required field missing', 'longMessage' => 'Required field shippingOptions is missing' } ] }
          )
          allow(response).to receive(:body).and_return('{"errors":[{"errorId":25007,"message":"Required field missing","longMessage":"Required field shippingOptions is missing"}]}')
          response
        end

        before do
          allow_any_instance_of(EbayApiClient).to receive(:create_fulfillment_policy)
            .and_return(error_response)
        end

        it 'prevents save and adds error messages' do
          policy = build(:ebay_fulfillment_policy,
            external_account: external_account,
            ebay_policy_id: nil
          )
          policy.ebay_policy_data = policy_data

          expect(policy.save).to be false
          expect(policy.errors[:base]).to include('Required field shippingOptions is missing')
          expect(policy.persisted?).to be false
        end
      end

      context 'when eBay API call raises exception' do
        before do
          allow_any_instance_of(EbayApiClient).to receive(:create_fulfillment_policy)
            .and_raise(StandardError, 'Network timeout')
        end

        it 'prevents save and adds error message' do
          policy = build(:ebay_fulfillment_policy,
            external_account: external_account,
            ebay_policy_id: nil
          )
          policy.ebay_policy_data = policy_data

          expect(policy.save).to be false
          expect(policy.errors[:base]).to include('Error creating policy: Network timeout')
          expect(policy.persisted?).to be false
        end
      end

      context 'when no ebay_policy_data is set' do
        it 'skips eBay API call and saves normally' do
          policy = build(:ebay_fulfillment_policy,
            external_account: external_account,
            ebay_policy_id: '12345678'
          )

          expect_any_instance_of(EbayApiClient).not_to receive(:create_fulfillment_policy)
          expect(policy.save).to be true
        end
      end
    end

    describe 'before_update callback' do
      let!(:existing_policy) do
        create(:ebay_fulfillment_policy,
          external_account: external_account,
          ebay_policy_id: '12345678'
        )
      end

      context 'when eBay API call succeeds' do
        let(:success_response) do
          EbayApiResponse.new(
            success: true,
            status_code: 200,
            data: { 'fulfillmentPolicyId' => '12345678' }
          )
        end

        before do
          allow_any_instance_of(EbayApiClient).to receive(:update_fulfillment_policy)
            .and_return(success_response)
        end

        it 'updates policy on eBay and saves locally' do
          existing_policy.ebay_policy_data = policy_data
          existing_policy.name = "Updated Policy Name"

          expect(existing_policy.save).to be true
          expect(existing_policy.name).to eq("Updated Policy Name")
        end
      end

      context 'when eBay API call fails' do
        let(:error_response) do
          response = EbayApiResponse.new(
            success: false,
            status_code: 400,
            error: { 'errors' => [ { 'errorId' => 25001, 'message' => 'Policy not found' } ] }
          )
          allow(response).to receive(:body).and_return('{"errors":[{"errorId":25001,"message":"Policy not found"}]}')
          response
        end

        before do
          allow_any_instance_of(EbayApiClient).to receive(:update_fulfillment_policy)
            .and_return(error_response)
        end

        it 'prevents save and adds error messages' do
          existing_policy.ebay_policy_data = policy_data
          existing_policy.name = "Updated Policy Name"

          expect(existing_policy.save).to be false
          expect(existing_policy.errors[:base]).to include('Policy not found')
        end
      end

      context 'when no ebay_policy_id is present' do
        it 'fails validation because persisted records require ebay_policy_id' do
          existing_policy.ebay_policy_id = nil
          existing_policy.ebay_policy_data = policy_data
          existing_policy.name = "Updated Name"

          expect_any_instance_of(EbayApiClient).not_to receive(:update_fulfillment_policy)
          expect(existing_policy.save).to be false
          expect(existing_policy.errors[:ebay_policy_id]).to include("can't be blank")
        end
      end

      context 'when no ebay_policy_data is set' do
        it 'skips eBay API call and saves normally' do
          existing_policy.name = "Updated Name"

          expect_any_instance_of(EbayApiClient).not_to receive(:update_fulfillment_policy)
          expect(existing_policy.save).to be true
        end
      end
    end
  end
end
