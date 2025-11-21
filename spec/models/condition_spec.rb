require 'rails_helper'

RSpec.describe Condition, type: :model do
  describe 'associations' do
    it 'belongs to an account' do
      expect(subject.account).to be_nil # until assigned
      account = create(:account)
      condition = create(:condition, account: account)
      expect(condition.account).to eq(account)
    end

    it 'has many variants with nullify dependency' do
      condition = create(:condition)
      variant = create(:variant, condition: condition)

      expect(condition.variants).to include(variant)
      condition.destroy
      expect(variant.reload.condition_id).to be_nil
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      condition = build(:condition, name: nil)
      expect(condition).not_to be_valid
      expect(condition.errors[:name]).to be_present
    end

    it 'validates presence of description' do
      condition = build(:condition, description: nil)
      expect(condition).not_to be_valid
      expect(condition.errors[:description]).to be_present
    end

    it 'validates uniqueness of name scoped to account' do
      account = create(:account)
      create(:condition, name: 'Test', account: account)

      duplicate = build(:condition, name: 'Test', account: account)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')

      # Different account should be valid
      other_account = create(:account)
      different_account_condition = build(:condition, name: 'Test', account: other_account)
      expect(different_account_condition).to be_valid
    end

    it 'validates eBay condition is in allowed list' do
      condition = build(:condition, ebay_condition: 'INVALID_CONDITION')
      expect(condition).not_to be_valid
      expect(condition.errors[:ebay_condition]).to be_present
    end

    it 'allows nil eBay condition' do
      condition = build(:condition, ebay_condition: nil)
      expect(condition).to be_valid
    end

    it 'allows valid eBay conditions' do
      condition = build(:condition, ebay_condition: 'NEW')
      expect(condition).to be_valid
    end
  end

  describe 'constants' do
    it 'defines EBAY_CONDITIONS' do
      expect(Condition::EBAY_CONDITIONS).to be_an(Array)
      expect(Condition::EBAY_CONDITIONS).to include('NEW', 'USED_EXCELLENT', 'CERTIFIED_REFURBISHED')
      expect(Condition::EBAY_CONDITIONS).to be_frozen
    end
  end

  describe '#ebay_condition_display_name' do
    context 'when ebay_condition is present' do
      let(:condition) { create(:condition, ebay_condition: 'USED_EXCELLENT') }

      it 'returns the titleized condition name' do
        expect(condition.ebay_condition_display_name).to eq('Used Excellent')
      end
    end

    context 'when ebay_condition is not present' do
      let(:condition) { create(:condition, ebay_condition: nil) }

      it 'returns nil' do
        expect(condition.ebay_condition_display_name).to be_nil
      end
    end

    it 'handles different eBay condition formats' do
      condition = create(:condition, ebay_condition: 'FOR_PARTS_OR_NOT_WORKING')
      expect(condition.ebay_condition_display_name).to eq('For Parts Or Not Working')
    end
  end

  describe 'scopes' do
    describe '.for_account' do
      let(:account1) { create(:account) }
      let(:account2) { create(:account) }
      let!(:condition1) { create(:condition, account: account1) }
      let!(:condition2) { create(:condition, account: account2) }

      it 'returns conditions for the specified account only' do
        expect(Condition.for_account(account1)).to contain_exactly(condition1)
        expect(Condition.for_account(account2)).to contain_exactly(condition2)
      end
    end
  end

  describe 'variant nullification on destroy' do
    let(:condition) { create(:condition) }
    let(:variant) { create(:variant, condition: condition) }

    it 'nullifies variant condition_id when destroyed' do
      expect { condition.destroy }.to change { variant.reload.condition_id }.to(nil)
    end
  end
end
