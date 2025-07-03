require 'rails_helper'

describe ExternalAccountProduct, type: :model do
  let(:account) { create(:account) }
  let(:external_account) { create(:external_account, account: account) }
  let(:product) { create(:product, account: account) }
  let(:external_account_product) { create(:external_account_product, external_account: external_account, product: product) }

  let(:shopify_response) do
    {
      "id" => "shopify_product_id",
      "options" => [
        { "id" => "shopify_option_id", "name" => "Color" }
      ],
      "variants" => [
        { "id" => "shopify_variant_id", "sku" => "SKU-1234" }
      ]
    }
  end

  before do
    allow_any_instance_of(Shopify).to receive(:publish_product).and_return(shopify_response)
  end

  describe 'after_save :sync_to_external_account' do
    it 'calls sync_to_external_account after save' do
      eap = build(:external_account_product, external_account: external_account, product: product)
      expect(eap).to receive(:sync_to_external_account)
      eap.save!
    end
  end

  describe '#sync_to_external_account' do
    it 'syncs to Shopify when called directly' do
      option = create(:product_option, product: product, name: "Color")
      variant = create(:variant, product: product, sku: "SKU-1234")
      external_account_product.update_column(:external_id, "shopify_product_id")
      expect_any_instance_of(Shopify).to receive(:publish_product).with(hash_including(id: "shopify_product_id")).and_return(shopify_response)
      external_account_product.sync_to_external_account
      expect(option.reload.external_id_for(external_account_product.id)).to eq("shopify_option_id")
      expect(variant.reload.external_id_for(external_account_product.id)).to eq("shopify_variant_id")
    end
  end
end
