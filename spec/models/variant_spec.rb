require 'rails_helper'

RSpec.describe Variant, type: :model do
  let(:account) { create(:account) }
  let(:product) { create(:product, account: account) }
  let(:variant) { build(:variant, product: product) }

  describe 'associations' do
    it 'belongs to a product' do
      product = create(:product)
      variant = create(:variant, product: product)
      expect(variant.product).to eq(product)
    end

    it 'belongs to a condition optionally' do
      variant = create(:variant)
      expect(variant.condition).to be_nil

      condition = create(:condition, account: variant.product.account)
      variant.update!(condition: condition)
      expect(variant.condition).to eq(condition)
    end

    it 'has many variant_option_values with destroy dependency' do
      variant = create(:variant)
      vov = create(:variant_option_value, variant: variant)

      expect(variant.variant_option_values).to include(vov)
      expect { variant.destroy }.to change { VariantOptionValue.count }.by(-1)
    end

    it 'has many inventory_units with destroy dependency' do
      variant = create(:variant)
      unit = create(:inventory_unit, variant: variant)

      expect(variant.inventory_units).to include(unit)
      expect { variant.destroy }.to change { InventoryUnit.count }.by(-1)
    end
  end

  describe 'validations' do
    it 'validates presence of sku' do
      variant = build(:variant, sku: nil)
      expect(variant).not_to be_valid
      expect(variant.errors[:sku]).to be_present
    end

    it 'validates uniqueness of sku scoped to product' do
      product = create(:product)
      create(:variant, sku: 'TEST-SKU', product: product)

      duplicate = build(:variant, sku: 'TEST-SKU', product: product)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sku]).to include('has already been taken')

      # Different product should be valid
      other_account = create(:account)
      other_product = create(:product, account: other_account, name: 'Other Product')
      different_product_variant = build(:variant, sku: 'TEST-SKU', product: other_product)
      expect(different_product_variant).to be_valid
    end

    it 'validates price is greater than or equal to 0' do
      variant = build(:variant, price: -1)
      expect(variant).not_to be_valid
      expect(variant.errors[:price]).to be_present

      variant.price = 0
      expect(variant).to be_valid

      variant.price = 10.50
      expect(variant).to be_valid
    end
  end

  describe '#suggested_sku' do
    context 'with no conditions or options' do
      it 'generates empty SKU when no model/condition/options' do
        expect(variant.suggested_sku).to eq('')
      end
    end

    context 'with condition but no options' do
      let(:condition) { create(:condition, name: 'New', account: account) }

      it 'includes only condition in SKU' do
        variant.condition = condition
        expect(variant.suggested_sku).to eq('NEW')
      end
    end

    context 'with model option and condition' do
      let(:condition) { create(:condition, name: 'Refurb', account: account) }
      let(:model_option) { create(:product_option, product: product, name: 'Model') }
      let(:model_value) { create(:product_option_value, product_option: model_option, value: 'iPhone 15') }

      before do
        variant.condition = condition
        variant.variant_option_values.build(
          product_option: model_option,
          product_option_value: model_value
        )
      end

      it 'orders SKU as Model + Condition + Other Options' do
        expect(variant.suggested_sku).to eq('IPHONE15REFURB')
      end
    end

    context 'with multiple options and condition' do
      let(:condition) { create(:condition, name: 'Used', account: account) }
      let(:color_option) { create(:product_option, product: product, name: 'Color') }
      let(:storage_option) { create(:product_option, product: product, name: 'Storage') }
      let(:color_value) { create(:product_option_value, product_option: color_option, value: 'Black') }
      let(:storage_value) { create(:product_option_value, product_option: storage_option, value: '256GB') }

      before do
        variant.condition = condition
        variant.variant_option_values.build(
          product_option: color_option,
          product_option_value: color_value
        )
        variant.variant_option_values.build(
          product_option: storage_option,
          product_option_value: storage_value
        )
      end

      it 'includes condition and all options' do
        result = variant.suggested_sku
        expect(result).to include('USED')
        expect(result).to include('BLACK')
        expect(result).to include('256GB')
      end
    end

    context 'with eBay aspects and condition' do
      let(:condition) { create(:condition, name: 'Mint', account: account) }

      before do
        product.update!(ebay_aspects: { 'Model' => 'iPhone 14' })
        variant.condition = condition
      end

      it 'uses eBay model aspect with condition' do
        expect(variant.suggested_sku).to eq('IPHONE14MINT')
      end
    end

    it 'removes spaces and converts to uppercase' do
      condition = create(:condition, name: 'Like New', account: account)
      variant.condition = condition

      expect(variant.suggested_sku).to eq('LIKENEW')
    end
  end

  describe '#title' do
    it 'returns the SKU as title' do
      variant.sku = 'TEST-SKU-123'
      expect(variant.title).to eq('TEST-SKU-123')
    end
  end
end
