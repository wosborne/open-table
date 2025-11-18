require 'rails_helper'

RSpec.describe TransactionNotificationHandler do
  let(:account) { create(:account) }
  let(:external_account) { create(:external_account, service_name: "ebay", ebay_username: "test_user", account: account) }
  let(:handler) { described_class.new(external_account) }

  let(:valid_transaction_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
        <soapenv:Body>
          <GetItemTransactionsResponse xmlns="urn:ebay:apis:eBLBaseComponents">
            <NotificationEventName>AuctionCheckoutComplete</NotificationEventName>
            <RecipientUserID>test_user</RecipientUserID>
            <Item>
              <ItemID>987654321</ItemID>
              <Title>Test Phone 256GB Black</Title>
            </Item>
            <TransactionArray>
              <Transaction>
                <TransactionID>123456789</TransactionID>
                <AmountPaid currencyID="GBP">899.99</AmountPaid>
                <TransactionPrice currencyID="GBP">899.99</TransactionPrice>
                <CreatedDate>2025-11-17T09:15:32.000Z</CreatedDate>
                <Status>
                  <CheckoutStatus>CheckoutComplete</CheckoutStatus>
                </Status>
                <ContainingOrder>
                  <OrderID>20-13830-48048</OrderID>
                  <OrderStatus>Completed</OrderStatus>
                </ContainingOrder>
              </Transaction>
            </TransactionArray>
          </GetItemTransactionsResponse>
        </soapenv:Body>
      </soapenv:Envelope>
    XML
  end

  let(:minimal_transaction_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <GetItemTransactionsResponse xmlns="urn:ebay:apis:eBLBaseComponents">
        <Item>
          <ItemID>987654321</ItemID>
        </Item>
        <TransactionArray>
          <Transaction>
            <TransactionID>123456789</TransactionID>
            <ContainingOrder>
              <OrderID>20-13830-48048</OrderID>
            </ContainingOrder>
          </Transaction>
        </TransactionArray>
      </GetItemTransactionsResponse>
    XML
  end

  let(:missing_required_data_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <GetItemTransactionsResponse xmlns="urn:ebay:apis:eBLBaseComponents">
        <TransactionArray>
          <Transaction>
            <TransactionPrice currencyID="GBP">899.99</TransactionPrice>
          </Transaction>
        </TransactionArray>
      </GetItemTransactionsResponse>
    XML
  end

  let(:malformed_xml) { "<invalid>xml" }

  before do
    # Mock eBay API sync callbacks to prevent real API calls during factory creation
    allow_any_instance_of(ExternalAccount).to receive(:sync_ebay_inventory_locations).and_return(true)
    allow_any_instance_of(ExternalAccount).to receive(:sync_ebay_business_policies).and_return(true)
  end

  describe '#process' do
    context 'with valid transaction XML' do
      it 'creates an order with transaction details' do
        expect { handler.process(valid_transaction_xml) }.to change { Order.count }.by(1)

        order = Order.last
        expect(order.external_account).to eq(external_account)
        expect(order.external_id).to eq("20-13830-48048")
        expect(order.name).to eq("#20-13830-48048")
        expect(order.currency).to eq("GBP")
        expect(order.total_price).to eq(899.99)
        expect(order.financial_status).to eq("paid")
        expect(order.fulfillment_status).to eq("fulfilled")
        expect(order.payment_status).to eq("CheckoutComplete")
        
        extra_details = JSON.parse(order.extra_details)
        expect(extra_details["ebay_transaction_id"]).to eq("123456789")
        expect(extra_details["ebay_item_id"]).to eq("987654321")
        expect(extra_details["ebay_item_title"]).to eq("Test Phone 256GB Black")
      end


      it 'updates existing order when order already exists' do
        existing_order = create(:order, external_account: external_account, external_id: "20-13830-48048", total_price: 500.0)
        
        expect { handler.process(valid_transaction_xml) }.not_to change { Order.count }

        existing_order.reload
        expect(existing_order.total_price).to eq(899.99)
        expect(existing_order.currency).to eq("GBP")
        expect(existing_order.financial_status).to eq("paid")
      end
    end

    context 'with minimal required data' do
      it 'creates an order with basic details' do
        expect { handler.process(minimal_transaction_xml) }.to change { Order.count }.by(1)

        order = Order.last
        expect(order.external_id).to eq("20-13830-48048")
        expect(order.currency).to eq("USD") # default
        expect(order.total_price).to eq(0.0) # no amount provided
      end
    end

    context 'with missing required data' do
      it 'does not create an order when required data is missing' do
        expect { handler.process(missing_required_data_xml) }.not_to change { Order.count }
      end

      it 'does not raise an error when required data is missing' do
        expect { handler.process(missing_required_data_xml) }.not_to raise_error
      end
    end

    context 'with malformed XML' do
      it 'does not raise an error for malformed XML' do
        expect { handler.process(malformed_xml) }.not_to raise_error
      end

      it 'returns nil for malformed XML' do
        allow(Rails.logger).to receive(:error)
        result = handler.process(malformed_xml)
        expect(result).to be_nil
      end
    end

    context 'when notification creation fails' do
      before do
        allow(SaleNotificationNotifier).to receive(:with).and_raise(StandardError.new("Notification failed"))
      end

      it 'raises the error' do
        expect { handler.process(valid_transaction_xml) }.to raise_error(StandardError, "Notification failed")
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error)
          .with(a_string_matching(/Transaction handler failed/))

        expect { handler.process(valid_transaction_xml) }.to raise_error(StandardError)
      end
    end
  end


  describe 'XML parsing' do
    it 'extracts all available transaction data' do
      parsed_data = handler.send(:parse_transaction_xml, valid_transaction_xml)
      
      expect(parsed_data[:transaction_id]).to eq("123456789")
      expect(parsed_data[:item_id]).to eq("987654321")
      expect(parsed_data[:order_id]).to eq("20-13830-48048")
      expect(parsed_data[:order_status]).to eq("Completed")
      expect(parsed_data[:amount_paid]).to eq("899.99")
      expect(parsed_data[:currency]).to eq("GBP")
      expect(parsed_data[:transaction_price]).to eq("899.99")
      expect(parsed_data[:item_title]).to eq("Test Phone 256GB Black")
      expect(parsed_data[:payment_status]).to eq("CheckoutComplete")
      expect(parsed_data[:created_date]).to eq("2025-11-17T09:15:32.000Z")
    end

    it 'handles missing optional fields gracefully' do
      parsed_data = handler.send(:parse_transaction_xml, minimal_transaction_xml)
      
      expect(parsed_data[:transaction_id]).to eq("123456789")
      expect(parsed_data[:order_id]).to eq("20-13830-48048")
      expect(parsed_data[:item_title]).to be_nil
      expect(parsed_data[:amount_paid]).to be_nil
    end

    it 'returns nil when required fields are missing' do
      parsed_data = handler.send(:parse_transaction_xml, missing_required_data_xml)
      expect(parsed_data).to be_nil
    end
  end

  describe 'status mapping' do
    describe '#map_financial_status' do
      it 'maps eBay payment statuses to financial statuses' do
        expect(handler.send(:map_financial_status, "CheckoutComplete")).to eq("paid")
        expect(handler.send(:map_financial_status, "NoPaymentFailure")).to eq("paid")
        expect(handler.send(:map_financial_status, "Pending")).to eq("pending")
        expect(handler.send(:map_financial_status, nil)).to eq("pending")
      end
    end

    describe '#map_fulfillment_status' do
      it 'maps eBay order statuses to fulfillment statuses' do
        expect(handler.send(:map_fulfillment_status, "Completed")).to eq("fulfilled")
        expect(handler.send(:map_fulfillment_status, "Active")).to eq("unfulfilled")
        expect(handler.send(:map_fulfillment_status, "Cancelled")).to eq("unfulfilled")
        expect(handler.send(:map_fulfillment_status, nil)).to eq("unfulfilled")
      end
    end

    describe '#build_order_extra_details' do
      it 'builds JSON string with eBay-specific details' do
        data = {
          transaction_id: "123456789",
          item_id: "987654321",
          item_title: "Test Phone",
          order_status: "Completed",
          payment_status: "CheckoutComplete"
        }

        result = handler.send(:build_order_extra_details, data)
        parsed = JSON.parse(result)

        expect(parsed["ebay_transaction_id"]).to eq("123456789")
        expect(parsed["ebay_item_id"]).to eq("987654321")
        expect(parsed["ebay_item_title"]).to eq("Test Phone")
        expect(parsed["ebay_order_status"]).to eq("Completed")
        expect(parsed["ebay_payment_status"]).to eq("CheckoutComplete")
      end

      it 'handles missing optional fields gracefully' do
        data = { transaction_id: "123456789" }
        result = handler.send(:build_order_extra_details, data)
        parsed = JSON.parse(result)

        expect(parsed["ebay_transaction_id"]).to eq("123456789")
        expect(parsed.keys).to eq(["ebay_transaction_id"])
      end
    end
  end
end