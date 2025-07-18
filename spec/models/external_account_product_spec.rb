require 'rails_helper'

RSpec.describe ExternalAccountProduct, type: :model do
  let(:account) { create(:account) }
  let(:external_account) { create(:external_account, account: account, service_name: "shopify") }
  let(:product) { create(:product_with_options, account: account) }
  let(:external_account_product) { create(:external_account_product, external_account: external_account, product: product) }

  let(:mock_shopify_service) { instance_double(Shopify) }
  let(:shopify_response) do
    {
      "id" => "12345",
      "title" => "Test Product",
      "options" => [
        { "id" => 1, "name" => "Color" },
        { "id" => 2, "name" => "Size" }
      ],
      "variants" => [
        { "id" => 101, "sku" => "TEST-RED-SMALL" },
        { "id" => 102, "sku" => "TEST-RED-LARGE" }
      ]
    }
  end

  before do
    # Mock the Shopify service creation
    allow(Shopify).to receive(:new).and_return(mock_shopify_service)
    allow(mock_shopify_service).to receive(:publish_product).and_return(shopify_response)
    
    # Mock external account webhook registration to prevent API calls
    allow_any_instance_of(ExternalAccount).to receive(:register_shopify_webhooks)
    
    # Set up product variants with prices to make them valid
    product.variants.each_with_index do |variant, index|
      variant.update!(price: 100 + (index * 10))
    end
  end

  describe 'callbacks' do
    it 'syncs to external account after save' do
      expect_any_instance_of(ExternalAccountProduct).to receive(:sync_to_external_account)
      
      ExternalAccountProduct.create!(external_account: external_account, product: product)
    end

    it 'removes from external account before destroy' do
      eap = create(:external_account_product, external_account: external_account, product: product, external_id: "12345")
      
      expect_any_instance_of(ExternalAccountProduct).to receive(:remove_from_external_account)
      
      eap.destroy
    end
  end

  describe '#sync_to_external_account' do
    it 'creates Shopify service with correct parameters' do
      expect(Shopify).to receive(:new).with(
        shop_domain: external_account.domain,
        access_token: external_account.api_token,
        external_account: external_account
      ).and_return(mock_shopify_service)

      external_account_product.sync_to_external_account
    end

    it 'publishes product with correct payload structure' do
      expected_payload = {
        title: product.name,
        variants: anything, # We'll test variants separately
        options: anything   # We'll test options separately
      }

      expect(mock_shopify_service).to receive(:publish_product).with(
        hash_including(expected_payload)
      ).and_return(shopify_response)

      external_account_product.sync_to_external_account
    end

    it 'includes external_id in payload for existing products' do
      external_account_product.update!(external_id: "existing_id")

      expect(mock_shopify_service).to receive(:publish_product).with(
        hash_including(id: "existing_id")
      ).and_return(shopify_response)

      external_account_product.sync_to_external_account
    end

    it 'does not include id for new products' do
      expect(mock_shopify_service).to receive(:publish_product).with(
        hash_not_including(:id)
      ).and_return(shopify_response)

      external_account_product.sync_to_external_account
    end

    it 'updates external_id after successful creation' do
      # Ensure external_id is initially blank
      external_account_product.update_column(:external_id, nil)
      expect(external_account_product.external_id).to be_blank
      
      expect(mock_shopify_service).to receive(:publish_product).and_return(shopify_response)
      
      expect {
        external_account_product.sync_to_external_account
      }.to change { external_account_product.reload.external_id }.from(nil).to("12345")
    end

    it 'syncs Shopify IDs after successful publish' do
      expect(external_account_product).to receive(:sync_shopify_ids).with(shopify_response)

      external_account_product.sync_to_external_account
    end
  end

  describe '#shopify_options' do
    let(:saved_external_account_product) do
      create(:external_account_product, external_account: external_account, product: product)
    end
    let(:color_option) { product.product_options.find_by(name: "Color") }
    let(:size_option) { product.product_options.find_by(name: "Size") }

    before do
      # Stub the callback to avoid API calls during creation
      allow_any_instance_of(ExternalAccountProduct).to receive(:sync_to_external_account)
      
      # Set external IDs for options using the actual method and reload to ensure they're persisted
      color_option.set_external_id_for(saved_external_account_product.id, "ext_color_1")
      size_option.set_external_id_for(saved_external_account_product.id, "ext_size_2")
      
      # Reload the product to ensure the options are fresh
      saved_external_account_product.product.reload
    end

    it 'returns options in Shopify format' do
      result = saved_external_account_product.send(:shopify_options)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      
      color_option_data = result.find { |opt| opt[:name] == "Color" }
      expect(color_option_data[:id]).to eq("ext_color_1")
      expect(color_option_data[:values]).to include("Red", "Blue")
      
      size_option_data = result.find { |opt| opt[:name] == "Size" }
      expect(size_option_data[:id]).to eq("ext_size_2")
      expect(size_option_data[:values]).to include("Small", "Large")
    end
  end

  describe '#shopify_variants' do
    it 'returns variants in Shopify format' do
      result = external_account_product.send(:shopify_variants)

      expect(result).to be_an(Array)
      expect(result.length).to be > 0
      
      first_variant = result.first
      expect(first_variant).to have_key(:id)
      expect(first_variant).to have_key(:sku)
      expect(first_variant).to have_key(:price)
    end

    it 'filters out variants with nil option values' do
      # Create a variant with missing option values
      incomplete_variant = product.variants.build
      incomplete_variant.sku = "INCOMPLETE"
      incomplete_variant.price = 99.99
      incomplete_variant.save!(validate: false)

      result = external_account_product.send(:shopify_variants)

      # Should not include the incomplete variant
      skus = result.map { |v| v[:sku] }
      expect(skus).not_to include("INCOMPLETE")
    end
  end
end