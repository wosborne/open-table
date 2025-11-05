require 'rails_helper'

RSpec.describe EbayBusinessPolicy, type: :model do
  let(:external_account) { create(:external_account, :ebay) }

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
        policy_type: 'fulfillment',
        ebay_policy_id: '12345678',
        name: 'Test Policy',
        marketplace_id: 'EBAY_GB'
      }
    end

    it 'validates presence of policy_type' do
      policy = build(:ebay_business_policy, valid_attributes.merge(policy_type: nil))
      expect(policy).not_to be_valid
      expect(policy.errors[:policy_type]).to include("can't be blank")
    end

    it 'validates presence of ebay_policy_id' do
      policy = build(:ebay_business_policy, valid_attributes.merge(ebay_policy_id: nil))
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

    it 'validates inclusion of policy_type in allowed values' do
      policy = build(:ebay_business_policy, valid_attributes.merge(policy_type: 'invalid'))
      expect(policy).not_to be_valid
      expect(policy.errors[:policy_type]).to include('is not included in the list')
    end

    it 'validates uniqueness of ebay_policy_id' do
      create(:ebay_business_policy, valid_attributes)
      duplicate_policy = build(:ebay_business_policy, valid_attributes)
      expect(duplicate_policy).not_to be_valid
      expect(duplicate_policy.errors[:ebay_policy_id]).to include('has already been taken')
    end

    it 'is valid with valid attributes' do
      policy = build(:ebay_business_policy, valid_attributes)
      expect(policy).to be_valid
    end
  end

  describe 'scopes' do
    let!(:fulfillment_policy) { create(:ebay_business_policy, policy_type: 'fulfillment', external_account: external_account) }
    let!(:payment_policy) { create(:ebay_business_policy, policy_type: 'payment', external_account: external_account) }
    let!(:return_policy) { create(:ebay_business_policy, policy_type: 'return', external_account: external_account) }

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
        policy = build(:ebay_business_policy, policy_type: 'fulfillment')
        expect(policy.fulfillment?).to be true
      end

      it 'returns false for non-fulfillment policy' do
        policy = build(:ebay_business_policy, policy_type: 'payment')
        expect(policy.fulfillment?).to be false
      end
    end

    describe '#payment?' do
      it 'returns true for payment policy' do
        policy = build(:ebay_business_policy, policy_type: 'payment')
        expect(policy.payment?).to be true
      end

      it 'returns false for non-payment policy' do
        policy = build(:ebay_business_policy, policy_type: 'fulfillment')
        expect(policy.payment?).to be false
      end
    end

    describe '#return?' do
      it 'returns true for return policy' do
        policy = build(:ebay_business_policy, policy_type: 'return')
        expect(policy.return?).to be true
      end

      it 'returns false for non-return policy' do
        policy = build(:ebay_business_policy, policy_type: 'payment')
        expect(policy.return?).to be false
      end
    end
  end

  describe 'factory' do
    it 'creates valid ebay business policy' do
      policy = build(:ebay_business_policy, external_account: external_account)
      expect(policy).to be_valid
    end

    it 'creates fulfillment policy with trait' do
      policy = build(:ebay_business_policy, :fulfillment, external_account: external_account)
      expect(policy.policy_type).to eq 'fulfillment'
      expect(policy.fulfillment?).to be true
    end

    it 'creates payment policy with trait' do
      policy = build(:ebay_business_policy, :payment, external_account: external_account)
      expect(policy.policy_type).to eq 'payment'
      expect(policy.payment?).to be true
    end

    it 'creates return policy with trait' do
      policy = build(:ebay_business_policy, :return, external_account: external_account)
      expect(policy.policy_type).to eq 'return'
      expect(policy.return?).to be true
    end
  end

  describe 'validation edge cases' do
    let(:valid_attributes) do
      {
        external_account: external_account,
        policy_type: 'fulfillment',
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
          ebay_policy_id: '',
          marketplace_id: ''
        )
      )

      expect(policy).not_to be_valid
      expect(policy.errors[:name]).to include("can't be blank")
      expect(policy.errors[:ebay_policy_id]).to include("can't be blank")
      expect(policy.errors[:marketplace_id]).to include("can't be blank")
    end
  end

  describe 'constants' do
    it 'defines correct policy types' do
      expect(described_class::POLICY_TYPES).to match_array(%w[fulfillment payment return])
    end

    it 'policy types are frozen' do
      expect(described_class::POLICY_TYPES).to be_frozen
    end
  end

  describe 'database constraints' do
    it 'enforces uniqueness at database level' do
      create(:ebay_business_policy, ebay_policy_id: '12345', external_account: external_account)

      expect {
        described_class.create!(
          ebay_policy_id: '12345',
          external_account: external_account,
          policy_type: 'payment',
          name: 'Test',
          marketplace_id: 'EBAY_GB'
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
