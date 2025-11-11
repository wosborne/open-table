require 'rails_helper'

RSpec.describe EbayFulfillmentPolicy, type: :model do
  include EbayApiMocking

  let(:external_account) { create(:external_account, :ebay) }
  let(:fulfillment_policy) { EbayFulfillmentPolicy.create!(external_account: external_account, name: 'Test Policy', marketplace_id: 'EBAY_GB', ebay_policy_id: '123456') }

  before do
    mock_ebay_api_responses
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#handling_time' do
    it 'returns handling time value from eBay attributes' do
      ebay_data = {
        'handlingTime' => { 'value' => 2, 'unit' => 'DAY' }
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.handling_time).to eq(2)
    end

    it 'returns nil when handling time is not present' do
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return({})

      expect(fulfillment_policy.handling_time).to be_nil
    end
  end

  describe '#service_code' do
    it 'returns shipping service code from first shipping service' do
      ebay_data = {
        'shippingOptions' => [
          {
            'shippingServices' => [
              { 'shippingServiceCode' => 'UK_RoyalMailFirstClass' }
            ]
          }
        ]
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.service_code).to eq('UK_RoyalMailFirstClass')
    end

    it 'returns nil when no shipping services exist' do
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return({})

      expect(fulfillment_policy.service_code).to be_nil
    end
  end

  describe '#free_shipping?' do
    it 'returns true when free shipping is enabled' do
      ebay_data = {
        'shippingOptions' => [
          {
            'shippingServices' => [
              { 'freeShipping' => true }
            ]
          }
        ]
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.free_shipping?).to be true
    end

    it 'returns false when free shipping is disabled' do
      ebay_data = {
        'shippingOptions' => [
          {
            'shippingServices' => [
              { 'freeShipping' => false }
            ]
          }
        ]
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.free_shipping?).to be false
    end

    it 'returns false when no shipping services exist' do
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return({})

      expect(fulfillment_policy.free_shipping?).to be false
    end
  end

  describe '#cost' do
    it 'returns shipping cost as float' do
      ebay_data = {
        'shippingOptions' => [
          {
            'shippingServices' => [
              {
                'shippingCost' => {
                  'value' => '5.99',
                  'currency' => 'GBP'
                }
              }
            ]
          }
        ]
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.cost).to eq(5.99)
    end

    it 'returns nil when no shipping cost is present' do
      ebay_data = {
        'shippingOptions' => [
          {
            'shippingServices' => [
              { 'freeShipping' => true }
            ]
          }
        ]
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.cost).to be_nil
    end
  end

  describe '#currency' do
    it 'returns shipping cost currency' do
      ebay_data = {
        'shippingOptions' => [
          {
            'shippingServices' => [
              {
                'shippingCost' => {
                  'value' => '5.99',
                  'currency' => 'EUR'
                }
              }
            ]
          }
        ]
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.currency).to eq('EUR')
    end

    it 'returns GBP as default currency when none specified' do
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return({})

      expect(fulfillment_policy.currency).to eq('GBP')
    end
  end

  describe '#category_default?' do
    it 'returns true when policy has default category type' do
      ebay_data = {
        'categoryTypes' => [
          { 'name' => 'ALL_EXCLUDING_MOTORS_VEHICLES', 'default' => true }
        ]
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.category_default?).to be true
    end

    it 'returns false when no default category type exists' do
      ebay_data = {
        'categoryTypes' => [
          { 'name' => 'SOME_CATEGORY', 'default' => false }
        ]
      }
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return(ebay_data)

      expect(fulfillment_policy.category_default?).to be false
    end

    it 'returns false when no category types exist' do
      allow(fulfillment_policy).to receive(:ebay_attributes).and_return({})

      expect(fulfillment_policy.category_default?).to be false
    end
  end

  describe 'inheritance' do
    it 'inherits from EbayBusinessPolicy' do
      expect(EbayFulfillmentPolicy.superclass).to eq(EbayBusinessPolicy)
    end

    it 'has correct policy type' do
      expect(fulfillment_policy.policy_type).to eq('fulfillment')
    end

    it 'has correct STI type' do
      expect(fulfillment_policy.type).to eq('EbayFulfillmentPolicy')
    end
  end
end