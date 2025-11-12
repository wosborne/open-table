require 'rails_helper'

RSpec.describe ExternalAccountInventoryUnit, type: :model do
  let(:account) { create(:account) }
  let(:ebay_account) { create(:external_account, :ebay, account: account) }
  let(:inventory_unit) { create(:inventory_unit, account: account) }
  let(:external_account_inventory_unit) do
    create(:external_account_inventory_unit, 
           external_account: ebay_account, 
           inventory_unit: inventory_unit)
  end

  describe "associations" do
    it "belongs to external_account" do
      expect(external_account_inventory_unit).to respond_to(:external_account)
      expect(external_account_inventory_unit.external_account).to eq(ebay_account)
    end

    it "belongs to inventory_unit" do
      expect(external_account_inventory_unit).to respond_to(:inventory_unit)
      expect(external_account_inventory_unit.inventory_unit).to eq(inventory_unit)
    end
  end

  describe "validations" do
    it "validates uniqueness of external_account_id scoped to inventory_unit_id" do
      create(:external_account_inventory_unit, 
             external_account: ebay_account, 
             inventory_unit: inventory_unit)
      
      duplicate = build(:external_account_inventory_unit,
                       external_account: ebay_account,
                       inventory_unit: inventory_unit)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_account_id]).to include("has already been taken")
    end

    it "allows same inventory_unit with different external_accounts" do
      shopify_account = create(:external_account, service_name: 'shopify', account: account)
      
      ebay_listing = create(:external_account_inventory_unit,
                           external_account: ebay_account,
                           inventory_unit: inventory_unit)
      
      shopify_listing = build(:external_account_inventory_unit,
                             external_account: shopify_account,
                             inventory_unit: inventory_unit)
      
      expect(shopify_listing).to be_valid
    end
  end

  describe "marketplace data helper methods" do
    describe "#published?" do
      it "returns false when marketplace_data is nil" do
        unit = build(:external_account_inventory_unit, marketplace_data: nil)
        expect(unit.published?).to be false
      end

      it "returns false when published key is missing" do
        unit = build(:external_account_inventory_unit, marketplace_data: {})
        expect(unit.published?).to be false
      end

      it "returns false when published is explicitly false" do
        unit = build(:external_account_inventory_unit, marketplace_data: { 'published' => false })
        expect(unit.published?).to be false
      end

      it "returns true when published is true" do
        unit = build(:external_account_inventory_unit, :published)
        expect(unit.published?).to be true
      end
    end

    describe "#listing_id" do
      it "returns nil when marketplace_data is nil" do
        unit = build(:external_account_inventory_unit, marketplace_data: nil)
        expect(unit.listing_id).to be_nil
      end

      it "returns the listing_id from marketplace_data" do
        unit = build(:external_account_inventory_unit, :published)
        expect(unit.listing_id).to be_present
        expect(unit.listing_id).to match(/listing_/)
      end
    end

    describe "#price" do
      it "returns nil when marketplace_data is nil" do
        unit = build(:external_account_inventory_unit, marketplace_data: nil)
        expect(unit.price).to be_nil
      end

      it "converts price string to float" do
        unit = build(:external_account_inventory_unit, :published)
        expect(unit.price).to eq(99.99)
      end

      it "handles missing price" do
        unit = build(:external_account_inventory_unit, marketplace_data: {})
        expect(unit.price).to be_nil
      end
    end

    describe "#listed_at" do
      it "returns nil when marketplace_data is nil" do
        unit = build(:external_account_inventory_unit, marketplace_data: nil)
        expect(unit.listed_at).to be_nil
      end

      it "parses valid timestamp" do
        timestamp = 1.hour.ago.iso8601
        unit = build(:external_account_inventory_unit, 
                    marketplace_data: { 'listed_at' => timestamp })
        expect(unit.listed_at).to be_within(1.second).of(Time.parse(timestamp))
      end

      it "handles invalid timestamp gracefully" do
        unit = build(:external_account_inventory_unit,
                    marketplace_data: { 'listed_at' => 'invalid-date' })
        expect(unit.listed_at).to be_nil
      end

      it "handles missing listed_at" do
        unit = build(:external_account_inventory_unit, marketplace_data: {})
        expect(unit.listed_at).to be_nil
      end
    end

    describe "#url" do
      it "returns the url from marketplace_data" do
        url = "https://www.ebay.co.uk/itm/123456789"
        unit = build(:external_account_inventory_unit,
                    marketplace_data: { 'url' => url })
        expect(unit.url).to eq(url)
      end

      it "returns nil when no url is set" do
        unit = build(:external_account_inventory_unit, marketplace_data: {})
        expect(unit.url).to be_nil
      end
    end

    describe "#status_label" do
      it "returns 'Not Listed' when no marketplace_data" do
        unit = build(:external_account_inventory_unit, marketplace_data: nil)
        expect(unit.status_label).to eq('Not Listed')
      end

      it "returns 'In eBay Inventory' when not published" do
        unit = build(:external_account_inventory_unit, marketplace_data: { 'published' => false })
        expect(unit.status_label).to eq('In eBay Inventory')
      end

      it "returns 'Live on eBay' when published" do
        unit = build(:external_account_inventory_unit, :published)
        expect(unit.status_label).to eq('Live on eBay')
      end
    end
  end


  describe "eBay cleanup callbacks" do
    describe "#remove_from_ebay" do
      let(:api_client) { instance_double(EbayApiClient) }
      let(:unit) { create(:external_account_inventory_unit, :with_ebay_account, inventory_unit: inventory_unit) }

      before do
        allow(EbayApiClient).to receive(:new).and_return(api_client)
        allow(api_client).to receive(:get_inventory_locations).and_return({ success: true, data: [] })
        allow(api_client).to receive(:get_fulfillment_policies).and_return({ success: true, data: [] })
        allow(api_client).to receive(:get_payment_policies).and_return({ success: true, data: [] })
        allow(api_client).to receive(:get_return_policies).and_return({ success: true, data: [] })
      end

      context "when external account is eBay" do
        it "calls eBay API to delete inventory item" do
          sku = unit.inventory_unit.variant.sku
          expect(api_client).to receive(:delete).with("/sell/inventory/v1/inventory_item/#{sku}")
                                                .and_return({ success: true })
          
          unit.destroy
        end

        it "logs success when deletion succeeds" do
          allow(api_client).to receive(:delete).and_return({ success: true })
          expect(Rails.logger).to receive(:info).with(/Successfully removed eBay inventory item/)
          
          unit.destroy
        end

        it "handles 404 errors gracefully" do
          allow(api_client).to receive(:delete).and_return({ 
            success: false, 
            status_code: 404 
          })
          expect(Rails.logger).to receive(:info).with(/already removed or not found/)
          
          unit.destroy
        end

        it "handles eBay item not found error gracefully" do
          allow(api_client).to receive(:delete).and_return({
            success: false,
            detailed_errors: [{ error_id: 25001 }]
          })
          expect(Rails.logger).to receive(:info).with(/already removed or not found/)
          
          unit.destroy
        end

        it "handles eBay resource not found error 25710 gracefully" do
          allow(api_client).to receive(:delete).and_return({
            success: false,
            detailed_errors: [{ error_id: 25710 }]
          })
          expect(Rails.logger).to receive(:info).with(/already removed or not found/)
          
          unit.destroy
        end

        it "prevents deletion when eBay API fails" do
          allow(api_client).to receive(:delete).and_return({ 
            success: false, 
            error: "API Error",
            status_code: 500
          })
          
          expect { unit.destroy }.to raise_error(/Failed to remove item from eBay/)
          expect(ExternalAccountInventoryUnit.exists?(unit.id)).to be true
        end

        it "prevents deletion when API raises exception" do
          allow(api_client).to receive(:delete).and_raise("Network error")
          
          expect { unit.destroy }.to raise_error("Network error")
          expect(ExternalAccountInventoryUnit.exists?(unit.id)).to be true
        end
      end

      context "when external account is not eBay" do
        let(:shopify_account) { create(:external_account, service_name: 'shopify', account: account) }
        let(:unit) { create(:external_account_inventory_unit, external_account: shopify_account, inventory_unit: inventory_unit) }

        it "skips eBay cleanup for non-eBay accounts" do
          expect(EbayApiClient).not_to receive(:new)
          unit.destroy
        end
      end
    end
  end

  describe "private helper methods" do
    let(:unit) { create(:external_account_inventory_unit, external_account: ebay_account, inventory_unit: inventory_unit) }

    describe "#update_marketplace_data" do
      it "merges new data into existing marketplace_data" do
        original_data = unit.marketplace_data.dup
        
        unit.send(:update_marketplace_data, { status: 'new_status', new_field: 'new_value' })
        unit.reload
        
        expect(unit.marketplace_data['status']).to eq('new_status')
        expect(unit.marketplace_data['new_field']).to eq('new_value')
        # Original data should still be present
        expect(unit.marketplace_data['sku']).to eq(original_data['sku'])
      end

      it "handles nil marketplace_data" do
        unit.update!(marketplace_data: nil)
        
        unit.send(:update_marketplace_data, { status: 'active' })
        unit.reload
        
        expect(unit.marketplace_data['status']).to eq('active')
      end
    end

    describe "#ebay_item_not_found?" do
      it "returns true for 404 status code" do
        result = { status_code: 404 }
        expect(unit.send(:ebay_item_not_found?, result)).to be true
      end

      it "returns true for error_id 25001" do
        result = { detailed_errors: [{ error_id: 25001 }] }
        expect(unit.send(:ebay_item_not_found?, result)).to be true
      end

      it "returns true for error_id 25710 (resource not found)" do
        result = { detailed_errors: [{ error_id: 25710 }] }
        expect(unit.send(:ebay_item_not_found?, result)).to be true
      end

      it "returns true for errorId 25710 in eBay response format" do
        result = { detailed_errors: [{ errorId: 25710 }] }
        expect(unit.send(:ebay_item_not_found?, result)).to be true
      end

      it "returns false for other errors" do
        result = { status_code: 500 }
        expect(unit.send(:ebay_item_not_found?, result)).to be false
        
        result = { detailed_errors: [{ error_id: 25002 }] }
        expect(unit.send(:ebay_item_not_found?, result)).to be false
        
        result = {}
        expect(unit.send(:ebay_item_not_found?, result)).to be false
      end
    end
  end
end