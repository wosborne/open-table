require 'rails_helper'

RSpec.describe InventoryUnit, type: :model do
  let(:variant) { create(:variant) }

  it "has a valid factory" do
    expect(build(:inventory_unit, variant: variant, serial_number: "SN123")).to be_valid
  end

  it "requires a serial_number" do
    unit = build(:inventory_unit, serial_number: nil, variant: variant)
    expect(unit).not_to be_valid
    expect(unit.errors[:serial_number]).to be_present
  end

  it "requires a unique serial_number" do
    create(:inventory_unit, serial_number: "SN123", variant: variant)
    unit = build(:inventory_unit, serial_number: "SN123", variant: variant)
    expect(unit).not_to be_valid
    expect(unit.errors[:serial_number]).to include("has already been taken")
  end

  it "belongs to a variant" do
    unit = build(:inventory_unit, variant: variant)
    expect(unit.variant).to eq(variant)
  end

  it "defines status enum" do
    unit = build(:inventory_unit, status: :in_stock, variant: variant)
    expect(unit).to be_in_stock
    unit.status = :sold
    expect(unit).to be_sold
  end

  it "scopes in_stock units" do
    in_stock = create(:inventory_unit, status: :in_stock, variant: variant, serial_number: "SN1")
    sold = create(:inventory_unit, status: :sold, variant: variant, serial_number: "SN2")
    expect(InventoryUnit.in_stock).to include(in_stock)
    expect(InventoryUnit.in_stock).not_to include(sold)
  end

  describe "eBay integration methods" do
    let(:account) { create(:account) }
    let(:ebay_account) { create(:external_account, :ebay, account: account) }
    let(:product) { create(:product, account: account, ebay_category_id: 177, ebay_aspects: { "Brand" => [ "Apple" ], "Model" => [ "iPhone" ] }) }
    let(:variant) { create(:variant, product: product) }
    let(:inventory_unit) { create(:inventory_unit, account: account, variant: variant) }

    describe "#ebay_listing" do
      it "returns the ebay listing for the given external account" do
        ebay_listing = create(:external_account_inventory_unit, external_account: ebay_account, inventory_unit: inventory_unit)
        expect(inventory_unit.ebay_listing(ebay_account)).to eq(ebay_listing)
      end

      it "returns nil when no listing exists" do
        expect(inventory_unit.ebay_listing(ebay_account)).to be_nil
      end
    end

    describe "#ebay_listing_for_account" do
      it "returns the ebay listing for the account's ebay external account" do
        ebay_listing = create(:external_account_inventory_unit, external_account: ebay_account, inventory_unit: inventory_unit)
        expect(inventory_unit.ebay_listing_for_account(account)).to eq(ebay_listing)
      end

      it "returns nil when account has no ebay external account" do
        expect(inventory_unit.ebay_listing_for_account(account)).to be_nil
      end
    end

    describe "#add_to_ebay_inventory" do
      context "when account has no eBay connection" do
        it "returns failure with appropriate message" do
          # Don't create ebay_account for this test
          result = inventory_unit.add_to_ebay_inventory
          expect(result[:success]).to be false
          expect(result[:message]).to include("No eBay account connected")
        end
      end

      context "when account has eBay connection" do
        let(:api_client) { instance_double(EbayApiClient) }
        let(:policy_client) { instance_double(EbayPolicyClient) }
        let(:inventory_response) { { success: true, data: {} } }
        let(:offer_response) { { success: true, data: { 'offerId' => 'offer123' } } }
        let(:policy_ids) do
          {
            fulfillment_policy_id: "fulfillment_123",
            payment_policy_id: "payment_456",
            return_policy_id: "return_789"
          }
        end

        before do
          ebay_account # ensure the ebay_account exists

          # Mock EbayApiClient
          allow(EbayApiClient).to receive(:new).with(ebay_account).and_return(api_client)
          allow(api_client).to receive(:put).and_return(inventory_response)
          allow(api_client).to receive(:post).and_return(offer_response)
          allow(api_client).to receive(:get).and_return({ success: true, data: [] })

          # Mock EbayPolicyClient
          allow(EbayPolicyClient).to receive(:new).with(ebay_account).and_return(policy_client)
          allow(policy_client).to receive(:get_all_default_policy_ids).and_return(policy_ids)
        end

        it "creates inventory item and offer successfully" do
          expect(api_client).to receive(:put).with(
            "/sell/inventory/v1/inventory_item/#{variant.sku}",
            anything
          ).and_return(inventory_response)

          expect(api_client).to receive(:post).with(
            "/sell/inventory/v1/offer",
            anything
          ).and_return(offer_response)

          result = inventory_unit.add_to_ebay_inventory

          expect(result[:success]).to be true
          expect(result[:message]).to include("Added to eBay inventory successfully")
          expect(result[:ebay_listing]).to be_present
        end

        it "creates ExternalAccountInventoryUnit with correct data" do
          inventory_unit.add_to_ebay_inventory

          ebay_listing = inventory_unit.reload.external_account_inventory_units.first
          expect(ebay_listing.external_account).to eq(ebay_account)
          expect(ebay_listing.marketplace_data['sku']).to eq(variant.sku)
          expect(ebay_listing.marketplace_data['published']).to be false
          expect(ebay_listing.marketplace_data['offer_id']).to eq('offer123')
        end

        it "handles inventory item creation failure" do
          allow(api_client).to receive(:put).and_return({ success: false, error: "API Error" })

          result = inventory_unit.add_to_ebay_inventory

          expect(result[:success]).to be false
          expect(result[:message]).to include("Failed to create eBay inventory item")
        end

        it "handles offer creation failure" do
          allow(api_client).to receive(:post).and_return({ success: false, error: "Offer Error" })

          result = inventory_unit.add_to_ebay_inventory

          expect(result[:success]).to be false
          expect(result[:message]).to include("Failed to create eBay offer")
        end

        it "handles existing offer gracefully" do
          existing_offer_error = {
            success: false,
            detailed_errors: [ { error_id: 25002, message: "Offer entity already exists for the SKU" } ]
          }
          allow(api_client).to receive(:post).and_return(existing_offer_error)

          result = inventory_unit.add_to_ebay_inventory

          expect(result[:success]).to be true
          expect(result[:ebay_listing]).to be_present
        end
      end
    end

    describe "#publish_ebay_offer" do
      let(:api_client) { instance_double(EbayApiClient) }
      let(:ebay_listing) { create(:external_account_inventory_unit, external_account: ebay_account, inventory_unit: inventory_unit) }
      let(:publish_response) { { success: true, data: { 'listingId' => 'listing456' } } }

      before do
        allow(EbayApiClient).to receive(:new).with(ebay_account).and_return(api_client)
        allow(api_client).to receive(:post).and_return(publish_response)
      end

      context "when account has no eBay connection" do
        it "returns failure with appropriate message" do
          # Ensure no eBay account exists for this test
          account.external_accounts.where(service_name: 'ebay').destroy_all

          result = inventory_unit.publish_ebay_offer
          expect(result[:success]).to be false
          expect(result[:message]).to include("No eBay account connected")
        end
      end

      context "when no unpublished listing exists" do
        before { ebay_account }

        it "returns failure when no listing exists" do
          result = inventory_unit.publish_ebay_offer
          expect(result[:success]).to be false
          expect(result[:message]).to include("No unpublished eBay inventory item found")
        end

        it "returns failure when listing is already published" do
          ebay_listing.update!(marketplace_data: ebay_listing.marketplace_data.merge('published' => true))
          result = inventory_unit.publish_ebay_offer
          expect(result[:success]).to be false
          expect(result[:message]).to include("No unpublished eBay inventory item found")
        end
      end

      context "when unpublished listing exists" do
        before do
          ebay_account
          ebay_listing
        end

        it "publishes the offer successfully" do
          offer_id = ebay_listing.marketplace_data['offer_id']
          expect(api_client).to receive(:post).with(
            "/sell/inventory/v1/offer/#{offer_id}/publish"
          ).and_return(publish_response)

          result = inventory_unit.publish_ebay_offer

          expect(result[:success]).to be true
          expect(result[:message]).to include("Published eBay offer successfully")

          ebay_listing.reload
          expect(ebay_listing.marketplace_data['published']).to be true
          expect(ebay_listing.marketplace_data['listing_id']).to eq('listing456')
        end

        it "handles publish failure" do
          allow(api_client).to receive(:post).and_return({ success: false, error: "Publish Error" })

          result = inventory_unit.publish_ebay_offer

          expect(result[:success]).to be false
          expect(result[:message]).to include("Failed to publish eBay offer")
        end

        it "returns failure when no offer_id is present" do
          ebay_listing.update!(marketplace_data: ebay_listing.marketplace_data.except('offer_id'))

          result = inventory_unit.publish_ebay_offer

          expect(result[:success]).to be false
          expect(result[:message]).to include("No offer ID found")
        end
      end
    end

    describe "#delete_ebay_draft" do
      context "when account has no eBay connection" do
        it "returns failure with appropriate message" do
          # Don't create ebay_account for this test
          result = inventory_unit.delete_ebay_draft
          expect(result[:success]).to be false
          expect(result[:message]).to include("No eBay account connected")
        end
      end

      context "when no eBay listing exists" do
        before { ebay_account }

        it "returns failure when no listing exists" do
          result = inventory_unit.delete_ebay_draft
          expect(result[:success]).to be false
          expect(result[:message]).to include("No eBay draft found to delete")
        end
      end

      context "when eBay listing exists" do
        let(:api_client) { instance_double(EbayApiClient) }
        let(:ebay_listing) { create(:external_account_inventory_unit, external_account: ebay_account, inventory_unit: inventory_unit) }
        let(:delete_response) { { success: true } }

        before do
          ebay_account
          ebay_listing

          allow(EbayApiClient).to receive(:new).with(ebay_account).and_return(api_client)
          allow(api_client).to receive(:delete).and_return(delete_response)
        end

        it "deletes the draft successfully" do
          sku = ebay_listing.marketplace_data['sku']
          expect(api_client).to receive(:delete).with(
            "/sell/inventory/v1/inventory_item/#{sku}"
          ).and_return(delete_response)

          result = inventory_unit.delete_ebay_draft

          expect(result[:success]).to be true
          expect(result[:message]).to include("eBay draft deleted successfully")
          expect { ebay_listing.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it "uses variant SKU when marketplace_data SKU is missing" do
          ebay_listing.update!(marketplace_data: ebay_listing.marketplace_data.except('sku'))

          expect(api_client).to receive(:delete).with(
            "/sell/inventory/v1/inventory_item/#{variant.sku}"
          ).and_return(delete_response)

          inventory_unit.delete_ebay_draft
        end

        it "handles deletion failure" do
          allow(api_client).to receive(:delete).and_return({ success: false, error: "Delete Error" })

          result = inventory_unit.delete_ebay_draft

          expect(result[:success]).to be false
          expect(result[:message]).to include("Failed to delete eBay draft")
          expect(ExternalAccountInventoryUnit.exists?(ebay_listing.id)).to be true
        end

        it "handles API exceptions" do
          allow(api_client).to receive(:delete).and_raise("Network error")

          result = inventory_unit.delete_ebay_draft

          expect(result[:success]).to be false
          expect(result[:message]).to include("eBay API error: Network error")
          expect(ExternalAccountInventoryUnit.exists?(ebay_listing.id)).to be true
        end
      end
    end

    describe "eBay data building methods" do
      let(:product_option1) { create(:product_option, name: "Color", product: product) }
      let(:product_option2) { create(:product_option, name: "Storage", product: product) }
      let(:color_value) { create(:product_option_value, product_option: product_option1, value: "Blue") }
      let(:storage_value) { create(:product_option_value, product_option: product_option2, value: "256GB") }

      before do
        create(:variant_option_value, variant: variant, product_option: product_option1, product_option_value: color_value)
        create(:variant_option_value, variant: variant, product_option: product_option2, product_option_value: storage_value)
      end

      describe "#build_ebay_title" do
        it "combines product name with variant option values" do
          expected_title = "#{product.name} - Blue - 256GB"
          expect(inventory_unit.send(:build_ebay_title)).to eq(expected_title)
        end

        it "handles products with no variant options" do
          variant_without_options = create(:variant, product: product)
          inventory_unit_simple = create(:inventory_unit, variant: variant_without_options)
          expect(inventory_unit_simple.send(:build_ebay_title)).to eq(product.name)
        end
      end

      describe "#build_ebay_description" do
        it "includes product description and variant details" do
          description = inventory_unit.send(:build_ebay_description)
          expect(description).to include(product.description)
          expect(description).to include("Color: Blue")
          expect(description).to include("Storage: 256GB")
        end

        it "uses fallback description when product description is blank" do
          product.update!(description: nil)
          description = inventory_unit.send(:build_ebay_description)
          expect(description).to include("#{product.name} - #{variant.sku}")
        end
      end

      describe "#build_ebay_aspects" do
        it "combines product aspects with variant option values" do
          aspects = inventory_unit.send(:build_ebay_aspects)

          expect(aspects["Brand"]).to eq([ "Apple" ])
          expect(aspects["Model"]).to eq([ "iPhone" ])
          expect(aspects["Color"]).to eq([ "Blue" ])
          expect(aspects["Storage"]).to eq([ "256GB" ])
        end

        it "handles Color/Colour marketplace differences" do
          aspects = inventory_unit.send(:build_ebay_aspects)

          # Should have both Color and Colour for EBAY_GB compatibility
          expect(aspects["Color"]).to eq([ "Blue" ])
          expect(aspects["Colour"]).to eq([ "Blue" ])
        end

        it "works with Colour option name (British spelling)" do
          product_option1.update!(name: "Colour")
          aspects = inventory_unit.send(:build_ebay_aspects)

          expect(aspects["Color"]).to eq([ "Blue" ])
          expect(aspects["Colour"]).to eq([ "Blue" ])
        end

        it "ensures all aspect values are arrays" do
          aspects = inventory_unit.send(:build_ebay_aspects)

          aspects.each do |name, value|
            expect(value).to be_an(Array), "Aspect '#{name}' should be an array, got #{value.class}"
          end
        end

        it "handles products with no ebay_aspects" do
          product.update!(ebay_aspects: nil)
          aspects = inventory_unit.send(:build_ebay_aspects)

          expect(aspects["Color"]).to eq([ "Blue" ])
          expect(aspects["Storage"]).to eq([ "256GB" ])
          expect(aspects.keys).not_to include("Brand", "Model")
        end
      end

      describe "#build_ebay_inventory_item_data" do
        it "builds complete inventory item structure" do
          data = inventory_unit.send(:build_ebay_inventory_item_data)

          expect(data[:product][:title]).to be_present
          expect(data[:product][:aspects]).to be_a(Hash)
          expect(data[:condition]).to eq("USED_EXCELLENT") # Default when no condition mapping
          expect(data[:availability][:shipToLocationAvailability][:quantity]).to eq(1)
          expect(data[:packageWeightAndSize]).to be_present
        end
        context "with variant condition mappings" do
          let(:condition) { create(:condition, :with_ebay_mapping, account: account, ebay_condition: "NEW") }
          let(:variant_with_condition) { create(:variant, product: product, condition: condition) }
          let(:inventory_unit_with_condition) { create(:inventory_unit, account: account, variant: variant_with_condition) }

          it "uses the mapped eBay condition" do
            data = inventory_unit_with_condition.send(:build_ebay_inventory_item_data)
            expect(data[:condition]).to eq("NEW")
          end
        end
      end

      describe "#ebay_condition_value" do
        context "when variant has a condition with eBay mapping" do
          let(:condition) { create(:condition, :with_ebay_mapping, account: account, ebay_condition: "CERTIFIED_REFURBISHED") }
          let(:variant_with_condition) { create(:variant, product: product, condition: condition) }
          let(:inventory_unit_with_condition) { create(:inventory_unit, account: account, variant: variant_with_condition) }

          it "returns the mapped eBay condition" do
            expect(inventory_unit_with_condition.send(:ebay_condition_value)).to eq("CERTIFIED_REFURBISHED")
          end
        end

        context "when variant has a condition without eBay mapping" do
          let(:condition) { create(:condition, account: account, ebay_condition: nil) }
          let(:variant_with_condition) { create(:variant, product: product, condition: condition) }
          let(:inventory_unit_with_condition) { create(:inventory_unit, account: account, variant: variant_with_condition) }

          it "falls back to default condition" do
            expect(inventory_unit_with_condition.send(:ebay_condition_value)).to eq("USED_EXCELLENT")
          end
        end

        context "when variant has no condition" do
          it "falls back to default condition" do
            expect(inventory_unit.send(:ebay_condition_value)).to eq("USED_EXCELLENT")
          end
        end
      end

      describe "#build_ebay_offer_data" do
        let(:policy_client) { instance_double(EbayPolicyClient) }
        let(:policy_ids) do
          {
            fulfillment_policy_id: "fulfillment_123",
            payment_policy_id: "payment_456",
            return_policy_id: "return_789"
          }
        end

        before do
          allow(EbayPolicyClient).to receive(:new).with(ebay_account).and_return(policy_client)
          allow(policy_client).to receive(:get_all_default_policy_ids).and_return(policy_ids)
        end

        it "builds complete offer structure with policies" do
          data = inventory_unit.send(:build_ebay_offer_data, ebay_account)

          expect(data[:sku]).to eq(variant.sku)
          expect(data[:marketplaceId]).to eq("EBAY_GB")
          expect(data[:format]).to eq("FIXED_PRICE")
          expect(data[:pricingSummary][:price][:value]).to eq(variant.price.to_s)
          expect(data[:pricingSummary][:price][:currency]).to eq("GBP")
          expect(data[:categoryId]).to eq(product.ebay_category_id.to_s)
          expect(data[:listingPolicies][:fulfillmentPolicyId]).to eq("fulfillment_123")
          expect(data[:listingPolicies][:paymentPolicyId]).to eq("payment_456")
          expect(data[:listingPolicies][:returnPolicyId]).to eq("return_789")
        end
      end

      describe "#build_ebay_image_urls" do
        it "returns empty array when no images attached" do
          urls = inventory_unit.send(:build_ebay_image_urls)
          expect(urls).to eq([])
        end

        it "builds URLs for attached images" do
          # Mock image attachment
          allow(inventory_unit.images).to receive(:attached?).and_return(true)
          mock_image = double("image")
          allow(inventory_unit.images).to receive(:map).and_yield(mock_image)
          allow(Rails.application.routes.url_helpers).to receive(:rails_blob_url)
            .with(mock_image, host: "https://5cb64db96b33.ngrok-free.app")
            .and_return("https://5cb64db96b33.ngrok-free.app/rails/active_storage/blobs/image123")

          urls = inventory_unit.send(:build_ebay_image_urls)
          expect(urls).to include("https://5cb64db96b33.ngrok-free.app/rails/active_storage/blobs/image123")
        end
      end
    end

    describe "eBay error handling helpers" do
      describe "#format_ebay_error" do
        it "formats detailed errors" do
          result = {
            detailed_errors: [
              { message: "Error 1" },
              { message: "Error 2" }
            ]
          }

          formatted = inventory_unit.send(:format_ebay_error, result)
          expect(formatted).to eq("Error 1, Error 2")
        end

        it "falls back to error field when no detailed errors" do
          result = { error: "Simple error message" }

          formatted = inventory_unit.send(:format_ebay_error, result)
          expect(formatted).to eq("Simple error message")
        end

        it "handles nil error gracefully" do
          result = {}

          formatted = inventory_unit.send(:format_ebay_error, result)
          expect(formatted).to eq("")
        end
      end

      describe "#offer_already_exists_error?" do
        it "returns true for offer already exists error" do
          result = {
            detailed_errors: [
              {
                error_id: 25002,
                message: "Offer entity already exists for the SKU"
              }
            ]
          }

          expect(inventory_unit.send(:offer_already_exists_error?, result)).to be true
        end

        it "returns false for different error_id" do
          result = {
            detailed_errors: [
              {
                error_id: 25001,
                message: "Item not found"
              }
            ]
          }

          expect(inventory_unit.send(:offer_already_exists_error?, result)).to be false
        end

        it "returns false when message doesn't match" do
          result = {
            detailed_errors: [
              {
                error_id: 25002,
                message: "Different error message"
              }
            ]
          }

          expect(inventory_unit.send(:offer_already_exists_error?, result)).to be false
        end

        it "returns false when no detailed errors" do
          result = {}
          expect(inventory_unit.send(:offer_already_exists_error?, result)).to be false
        end
      end
    end
  end
end
