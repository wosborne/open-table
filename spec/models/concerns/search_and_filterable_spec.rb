require 'rails_helper'

RSpec.describe SearchAndFilterable, type: :module do
  let(:dummy_class) do
    Class.new do
      include SearchAndFilterable

      attr_accessor :params

      def initialize(params = {})
        @params = params
      end
    end
  end

  let(:account) { create(:account) }
  let!(:product1) { create(:product, account: account, name: "iPhone 15", description: "Apple smartphone", brand: "Apple") }
  let!(:product2) { create(:product, account: account, name: "Samsung Galaxy", description: "Samsung smartphone", brand: "Samsung") }
  let!(:product3) { create(:product, account: account, name: "Google Pixel", description: "Google smartphone", brand: "Google") }
  let(:scope) { Product.where(account: account) }
  let(:instance) { dummy_class.new }

  describe '#search_and_filter_records' do
    context 'without search or filters' do
      it 'returns all records limited to 100' do
        instance.params = {}
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(3)
        expect(result.to_sql).to include('LIMIT 100')
      end
    end

    context 'with search parameter' do
      it 'filters records based on search term in name' do
        instance.params = { search: 'iPhone' }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.name).to eq('iPhone 15')
      end

      it 'searches across multiple searchable attributes' do
        instance.params = { search: 'Apple' }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.brand).to eq('Apple')
      end

      it 'performs case insensitive search' do
        instance.params = { search: 'iphone' }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.name).to eq('iPhone 15')
      end

      it 'performs partial matching' do
        instance.params = { search: 'Sam' }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.name).to eq('Samsung Galaxy')
      end
    end

    context 'with filters parameter' do
      it 'filters records based on attribute filters' do
        filters = { name: 'iPhone' }.to_json
        instance.params = { filters: filters }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.name).to eq('iPhone 15')
      end

      it 'filters with partial matching' do
        filters = { brand: 'Goo' }.to_json
        instance.params = { filters: filters }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.brand).to eq('Google')
      end

      it 'ignores invalid attributes in filters' do
        filters = { invalid_attribute: 'test', name: 'iPhone' }.to_json
        instance.params = { filters: filters }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.name).to eq('iPhone 15')
      end
    end

    context 'with both search and filters' do
      it 'applies both search and filters' do
        filters = { brand: 'Apple' }.to_json
        instance.params = { search: '15', filters: filters }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.name).to eq('iPhone 15')
      end

      it 'returns empty when search and filters do not match' do
        filters = { brand: 'Samsung' }.to_json
        instance.params = { search: 'iPhone', filters: filters }
        result = instance.search_and_filter_records(scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(0)
      end
    end

    context 'limit functionality' do
      it 'limits results to 100 records' do
        # Create more than 100 products
        101.times do |i|
          create(:product, account: account, name: "Product #{i}", description: "Description #{i}")
        end

        instance.params = {}
        result = instance.search_and_filter_records(Product.where(account: account))

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(100)
      end
    end
  end

  describe '#search_records' do
    it 'searches across all searchable attributes' do
      instance.params = { search: 'iPhone' }
      result = instance.send(:search_records, scope)

      expect(result).to be_an(ActiveRecord::Relation)
      expect(result.to_sql).to include('ILIKE')
      expect(result.count).to eq(1)
    end

    it 'returns unmodified scope when search term is blank' do
      instance.params = { search: '' }
      result = instance.send(:search_records, scope)

      expect(result).to be_an(ActiveRecord::Relation)
      expect(result.count).to eq(3)
    end

    it 'searches numeric fields when search term is numeric' do
      instance.params = { search: product1.id.to_s }
      result = instance.send(:search_records, scope)

      expect(result).to be_an(ActiveRecord::Relation)
      expect(result.count).to eq(1)
      expect(result.first).to eq(product1)
    end

    it 'does not search numeric fields when search term is not numeric' do
      instance.params = { search: 'abc123' }
      result = instance.send(:search_records, scope)

      expect(result).to be_an(ActiveRecord::Relation)
      # Should only search text fields, not try to convert 'abc123' to integer
      expect(result.count).to eq(0)
    end

    it 'handles search terms with special SQL characters safely' do
      instance.params = { search: "'; DROP TABLE products; --" }
      result = instance.send(:search_records, scope)

      expect(result).to be_an(ActiveRecord::Relation)
      expect(result.count).to eq(0) # SQL injection prevented, no matches
    end
  end

  describe '#filter_records' do
    context 'with valid filters' do
      it 'applies filters to the scope' do
        instance.params = { filters: { name: 'iPhone' }.to_json }
        result = instance.send(:filter_records, scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.to_sql).to include('ILIKE')
        expect(result.count).to eq(1)
      end
    end

    context 'with invalid JSON filters' do
      it 'raises JSON parse error' do
        instance.params = { filters: 'invalid json' }

        expect {
          instance.send(:filter_records, scope)
        }.to raise_error(JSON::ParserError)
      end
    end

    context 'with empty filters' do
      it 'returns the original scope' do
        instance.params = { filters: '{}' }
        result = instance.send(:filter_records, scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(3)
      end
    end

    context 'with invalid attributes in filters' do
      it 'ignores invalid attributes and applies valid ones' do
        instance.params = { filters: { invalid_attribute: 'test', name: 'iPhone' }.to_json }
        result = instance.send(:filter_records, scope)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(1)
        expect(result.first.name).to eq('iPhone 15')
      end
    end
  end
end
