require 'rails_helper'

RSpec.describe CreateShopifyOrderJob, type: :job do
  let(:shop_domain) { "test-shop.myshopify.com" }
  let(:external_account) { create(:external_account, service_name: "shopify", domain: shop_domain) }
  let(:product) { create(:product, account: external_account.account) }
  let(:variant) { create(:variant, product: product, sku: "TEST-SKU-001") }
  let(:inventory_unit) { create(:inventory_unit, variant: variant, status: :in_stock) }

  before do
    # Mock external account webhook registration to prevent API calls
    allow_any_instance_of(ExternalAccount).to receive(:register_shopify_webhooks)

    # Set up ActiveJob test adapter
    ActiveJob::Base.queue_adapter = :test
  end

  let(:webhook_data) do
    {
      id: 450789469,
      name: "#1001",
      currency: "USD",
      total_price: "199.99",
      created_at: "2024-07-21T10:00:00-04:00",
      financial_status: "paid",
      fulfillment_status: nil,
      line_items: [
        {
          id: 866550311766,
          sku: "TEST-SKU-001",
          title: "Test Product - Red / Small",
          quantity: 2,
          price: "99.99"
        }
      ]
    }
  end

  describe '#perform' do
    context 'with valid external account' do
      it 'creates a new order successfully' do
        # Ensure all required records are created
        inventory_unit # This triggers creation of the entire chain

        expect {
          described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)
        }.to change(Order, :count).by(1)

        order = Order.last
        expect(order.external_account).to eq(external_account)
        expect(order.external_id).to eq("450789469")
        expect(order.name).to eq("#1001")
        expect(order.currency).to eq("USD")
        expect(order.total_price).to eq(199.99)
        expect(order.financial_status).to eq("paid")
        expect(order.fulfillment_status).to be_nil
      end

      it 'creates order line items' do
        # Ensure all required records are created
        inventory_unit

        described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)

        order = Order.last
        expect(order.order_line_items.count).to eq(1)

        line_item = order.order_line_items.first
        expect(line_item.external_line_item_id).to eq("866550311766")
        expect(line_item.sku).to eq("TEST-SKU-001")
        expect(line_item.title).to eq("Test Product - Red / Small")
        expect(line_item.quantity).to eq(2)
        expect(line_item.price).to eq(99.99)
      end

      it 'assigns inventory unit to line item' do
        inventory_unit # Ensure creation

        described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)

        line_item = Order.last.order_line_items.first
        expect(line_item.inventory_unit).to eq(inventory_unit)
      end

      it 'reserves inventory unit when assigned' do
        inventory_unit # Ensure creation

        expect {
          described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)
        }.to change { inventory_unit.reload.status }.from('in_stock').to('reserved')
      end

      it 'handles multiple line items' do
        variant2 = create(:variant, product: product, sku: "TEST-SKU-002")
        inventory_unit2 = create(:inventory_unit, variant: variant2, status: :in_stock)

        webhook_with_multiple_items = webhook_data.merge(
          line_items: [
            webhook_data[:line_items].first,
            {
              id: 866550311767,
              sku: "TEST-SKU-002",
              title: "Test Product - Blue / Large",
              quantity: 1,
              price: "129.99"
            }
          ]
        )

        described_class.perform_now(shop_domain: shop_domain, webhook: webhook_with_multiple_items)

        order = Order.last
        expect(order.order_line_items.count).to eq(2)

        skus = order.order_line_items.pluck(:sku)
        expect(skus).to include("TEST-SKU-001", "TEST-SKU-002")
      end

      it 'finds oldest available inventory unit for variant' do
        # Create multiple inventory units for the same variant
        old_unit = create(:inventory_unit, variant: variant, status: :in_stock, created_at: 1.day.ago)
        newer_unit = create(:inventory_unit, variant: variant, status: :in_stock, created_at: 1.hour.ago)

        described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)

        line_item = Order.last.order_line_items.first
        expect(line_item.inventory_unit).to eq(old_unit)
        expect(old_unit.reload.status).to eq('reserved')
        expect(newer_unit.reload.status).to eq('in_stock')
      end
    end

    context 'updating existing orders' do
      let!(:existing_order) do
        create(:order,
          external_account: external_account,
          external_id: "450789469",
          name: "#1001-OLD",
          total_price: 150.00
        )
      end

      it 'updates existing order instead of creating new one' do
        expect {
          described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)
        }.not_to change(Order, :count)

        existing_order.reload
        expect(existing_order.name).to eq("#1001")
        expect(existing_order.total_price).to eq(199.99)
        expect(existing_order.currency).to eq("USD")
      end

      it 'removes existing line items before creating new ones' do
        old_line_item = create(:order_line_item, order: existing_order, sku: "OLD-SKU")

        described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)

        existing_order.reload
        expect(existing_order.order_line_items.count).to eq(1)
        expect(existing_order.order_line_items.first.sku).to eq("TEST-SKU-001")
        expect { old_line_item.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with missing variant' do
      let(:webhook_with_unknown_sku) do
        webhook_data.merge(
          line_items: [
            {
              id: 866550311766,
              sku: "UNKNOWN-SKU",
              title: "Unknown Product",
              quantity: 1,
              price: "99.99"
            }
          ]
        )
      end

      it 'creates line item without inventory unit' do
        external_account # Ensure creation

        described_class.perform_now(shop_domain: shop_domain, webhook: webhook_with_unknown_sku)

        line_item = Order.last.order_line_items.first
        expect(line_item.sku).to eq("UNKNOWN-SKU")
        expect(line_item.inventory_unit).to be_nil
      end

      it 'does not fail when variant not found' do
        expect {
          described_class.perform_now(shop_domain: shop_domain, webhook: webhook_with_unknown_sku)
        }.not_to raise_error
      end
    end

    context 'with no available inventory' do
      before do
        inventory_unit.update!(status: :sold)
      end

      it 'creates line item without inventory unit' do
        described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)

        line_item = Order.last.order_line_items.first
        expect(line_item.inventory_unit).to be_nil
      end

      it 'does not change inventory unit status' do
        expect {
          described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)
        }.not_to change { inventory_unit.reload.status }
      end
    end

    context 'with invalid shop domain' do
      let(:invalid_shop_domain) { "nonexistent-shop.myshopify.com" }

      it 'does not create order for non-existent external account' do
        expect {
          described_class.perform_now(shop_domain: invalid_shop_domain, webhook: webhook_data)
        }.not_to change(Order, :count)
      end

      it 'returns early without error' do
        expect {
          described_class.perform_now(shop_domain: invalid_shop_domain, webhook: webhook_data)
        }.not_to raise_error
      end
    end

    context 'with malformed webhook data' do
      let(:malformed_webhook) do
        {
          id: nil,
          name: nil,
          line_items: nil
        }
      end

      it 'handles missing line_items gracefully' do
        external_account # Ensure creation

        expect {
          described_class.perform_now(shop_domain: shop_domain, webhook: malformed_webhook)
        }.not_to raise_error

        # No order should be created with nil id
        expect(Order.count).to eq(0)
      end

      it 'does not create order with nil id' do
        external_account # Ensure creation

        described_class.perform_now(shop_domain: shop_domain, webhook: malformed_webhook)

        # No order should be created when id is nil
        expect(Order.count).to eq(0)
      end
    end

    context 'date parsing' do
      it 'parses external_created_at correctly' do
        inventory_unit # Ensure creation

        described_class.perform_now(shop_domain: shop_domain, webhook: webhook_data)

        order = Order.last
        expect(order.external_created_at).to be_present
        expect(order.external_created_at).to be_a(Time)
      end

      it 'handles missing created_at' do
        inventory_unit # Ensure creation

        webhook_without_date = webhook_data.except(:created_at)

        expect {
          described_class.perform_now(shop_domain: shop_domain, webhook: webhook_without_date)
        }.not_to raise_error

        order = Order.last
        # Should use current time as default when created_at is missing
        expect(order.external_created_at).to be_present
        expect(order.external_created_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe 'job configuration' do
    it 'is queued on default queue' do
      expect(described_class.queue_name).to eq('default')
    end

    it 'can be performed later' do
      expect {
        described_class.perform_later(shop_domain: shop_domain, webhook: webhook_data)
      }.to have_enqueued_job(described_class).with(shop_domain: shop_domain, webhook: webhook_data)
    end
  end
end
