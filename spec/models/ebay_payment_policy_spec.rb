require 'rails_helper'

RSpec.describe EbayPaymentPolicy, type: :model do
  include EbayApiMocking

  let(:external_account) { create(:external_account, :ebay) }
  let(:payment_policy) { EbayPaymentPolicy.create!(external_account: external_account, name: 'Test Policy', marketplace_id: 'EBAY_GB', ebay_policy_id: '123456') }

  before do
    mock_ebay_api_responses
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#immediate_pay?' do
    it 'returns true when immediate pay is required' do
      ebay_data = { 'immediatePay' => true }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.immediate_pay?).to be true
    end

    it 'returns false when immediate pay is not required' do
      ebay_data = { 'immediatePay' => false }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.immediate_pay?).to be false
    end

    it 'returns false when immediate pay is not present' do
      allow(payment_policy).to receive(:ebay_attributes).and_return({})

      expect(payment_policy.immediate_pay?).to be false
    end
  end

  describe '#payment_methods' do
    it 'returns payment methods array' do
      ebay_data = {
        'paymentMethods' => [
          { 'paymentMethodType' => 'PAYPAL' },
          { 'paymentMethodType' => 'CREDIT_CARD' }
        ]
      }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.payment_methods).to eq([
        { 'paymentMethodType' => 'PAYPAL' },
        { 'paymentMethodType' => 'CREDIT_CARD' }
      ])
    end

    it 'returns empty array when no payment methods exist' do
      allow(payment_policy).to receive(:ebay_attributes).and_return({})

      expect(payment_policy.payment_methods).to eq([])
    end
  end

  describe '#payment_instructions' do
    it 'returns payment instructions' do
      ebay_data = { 'paymentInstructions' => 'Please pay within 3 days' }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.payment_instructions).to eq('Please pay within 3 days')
    end

    it 'returns nil when no payment instructions exist' do
      allow(payment_policy).to receive(:ebay_attributes).and_return({})

      expect(payment_policy.payment_instructions).to be_nil
    end
  end

  describe '#category_default?' do
    it 'returns true when policy has default category type' do
      ebay_data = {
        'categoryTypes' => [
          { 'name' => 'ALL_EXCLUDING_MOTORS_VEHICLES', 'default' => true }
        ]
      }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.category_default?).to be true
    end

    it 'returns false when no default category type exists' do
      allow(payment_policy).to receive(:ebay_attributes).and_return({})

      expect(payment_policy.category_default?).to be false
    end
  end

  describe '#deposit_details' do
    it 'returns deposit details object' do
      ebay_data = {
        'depositDetails' => {
          'dueIn' => { 'value' => 7, 'unit' => 'DAY' },
          'depositAmount' => { 'value' => '100.00', 'currency' => 'GBP' }
        }
      }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.deposit_details).to eq({
        'dueIn' => { 'value' => 7, 'unit' => 'DAY' },
        'depositAmount' => { 'value' => '100.00', 'currency' => 'GBP' }
      })
    end

    it 'returns nil when no deposit details exist' do
      allow(payment_policy).to receive(:ebay_attributes).and_return({})

      expect(payment_policy.deposit_details).to be_nil
    end
  end

  describe '#full_payment_due_in' do
    it 'returns full payment due in value' do
      ebay_data = {
        'depositDetails' => {
          'dueIn' => { 'value' => 7, 'unit' => 'DAY' }
        }
      }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.full_payment_due_in).to eq(7)
    end

    it 'returns nil when no deposit details exist' do
      allow(payment_policy).to receive(:ebay_attributes).and_return({})

      expect(payment_policy.full_payment_due_in).to be_nil
    end
  end

  describe '#deposit_amount' do
    it 'returns deposit amount as float' do
      ebay_data = {
        'depositDetails' => {
          'depositAmount' => { 'value' => '250.50', 'currency' => 'GBP' }
        }
      }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.deposit_amount).to eq(250.50)
    end

    it 'returns nil when no deposit amount exists' do
      allow(payment_policy).to receive(:ebay_attributes).and_return({})

      expect(payment_policy.deposit_amount).to be_nil
    end
  end

  describe '#deposit_currency' do
    it 'returns deposit currency' do
      ebay_data = {
        'depositDetails' => {
          'depositAmount' => { 'value' => '100.00', 'currency' => 'EUR' }
        }
      }
      allow(payment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(payment_policy.deposit_currency).to eq('EUR')
    end

    it 'returns GBP as default when no deposit details exist' do
      allow(payment_policy).to receive(:ebay_attributes).and_return({})

      expect(payment_policy.deposit_currency).to eq('GBP')
    end
  end

  describe 'inheritance' do
    it 'inherits from EbayBusinessPolicy' do
      expect(EbayPaymentPolicy.superclass).to eq(EbayBusinessPolicy)
    end

    it 'has correct policy type' do
      expect(payment_policy.policy_type).to eq('payment')
    end

    it 'has correct STI type' do
      expect(payment_policy.type).to eq('EbayPaymentPolicy')
    end
  end
end
