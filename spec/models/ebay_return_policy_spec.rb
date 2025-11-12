require 'rails_helper'

RSpec.describe EbayReturnPolicy, type: :model do
  include EbayApiMocking

  let(:external_account) { create(:external_account, :ebay) }
  let(:return_policy) { EbayReturnPolicy.create!(external_account: external_account, name: 'Test Policy', marketplace_id: 'EBAY_GB', ebay_policy_id: '123456') }

  before do
    mock_ebay_api_responses
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#returns_accepted?' do
    it 'returns true when returns are accepted' do
      ebay_data = { 'returnsAccepted' => true }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.returns_accepted?).to be true
    end

    it 'returns false when returns are not accepted' do
      ebay_data = { 'returnsAccepted' => false }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.returns_accepted?).to be false
    end

    it 'returns false when returns accepted is not present' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.returns_accepted?).to be false
    end
  end

  describe '#return_period' do
    it 'returns return period value' do
      ebay_data = {
        'returnPeriod' => { 'value' => 30, 'unit' => 'DAY' }
      }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.return_period).to eq(30)
    end

    it 'returns nil when no return period exists' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.return_period).to be_nil
    end
  end

  describe '#return_period_unit' do
    it 'returns return period unit' do
      ebay_data = {
        'returnPeriod' => { 'value' => 30, 'unit' => 'DAY' }
      }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.return_period_unit).to eq('DAY')
    end

    it 'returns nil when no return period exists' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.return_period_unit).to be_nil
    end
  end

  describe '#return_method' do
    it 'returns return method' do
      ebay_data = { 'returnMethod' => 'REPLACEMENT' }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.return_method).to eq('REPLACEMENT')
    end

    it 'returns nil when no return method exists' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.return_method).to be_nil
    end
  end

  describe '#return_shipping_cost_payer' do
    it 'returns who pays return shipping' do
      ebay_data = { 'returnShippingCostPayer' => 'BUYER' }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.return_shipping_cost_payer).to eq('BUYER')
    end

    it 'returns nil when no return shipping cost payer exists' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.return_shipping_cost_payer).to be_nil
    end
  end

  describe '#refund_method' do
    it 'returns refund method' do
      ebay_data = { 'refundMethod' => 'MONEY_BACK' }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.refund_method).to eq('MONEY_BACK')
    end

    it 'returns nil when no refund method exists' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.refund_method).to be_nil
    end
  end

  describe '#restocking_fee_percentage' do
    it 'returns restocking fee percentage as float' do
      ebay_data = { 'restockingFeePercentage' => '10.0' }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.restocking_fee_percentage).to eq(10.0)
    end

    it 'returns nil when no restocking fee exists' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.restocking_fee_percentage).to be_nil
    end
  end

  describe '#extended_holiday_returns?' do
    it 'returns true when extended holiday returns are enabled' do
      ebay_data = { 'extendedHolidayReturns' => true }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.extended_holiday_returns?).to be true
    end

    it 'returns false when extended holiday returns are disabled' do
      ebay_data = { 'extendedHolidayReturns' => false }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.extended_holiday_returns?).to be false
    end

    it 'returns false when extended holiday returns is not present' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.extended_holiday_returns?).to be false
    end
  end

  describe '#return_instructions' do
    it 'returns return instructions' do
      ebay_data = { 'returnInstructions' => 'Please contact us before returning items' }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.return_instructions).to eq('Please contact us before returning items')
    end

    it 'returns nil when no return instructions exist' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.return_instructions).to be_nil
    end
  end

  describe '#category_default?' do
    it 'returns true when policy has default category type' do
      ebay_data = {
        'categoryTypes' => [
          { 'name' => 'ALL_EXCLUDING_MOTORS_VEHICLES', 'default' => true }
        ]
      }
      allow(return_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(return_policy.category_default?).to be true
    end

    it 'returns false when no default category type exists' do
      allow(return_policy).to receive(:ebay_attributes).and_return({})

      expect(return_policy.category_default?).to be false
    end
  end

  describe 'inheritance' do
    it 'inherits from EbayBusinessPolicy' do
      expect(EbayReturnPolicy.superclass).to eq(EbayBusinessPolicy)
    end

    it 'has correct policy type' do
      expect(return_policy.policy_type).to eq('return')
    end

    it 'has correct STI type' do
      expect(return_policy.type).to eq('EbayReturnPolicy')
    end
  end
end