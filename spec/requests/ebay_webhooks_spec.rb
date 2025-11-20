require 'rails_helper'

RSpec.describe 'eBay Webhooks', type: :request do
  let!(:external_account) { create(:external_account, service_name: "ebay", ebay_username: "test_user") }

  let(:transaction_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <GetItemTransactionsResponse xmlns="urn:ebay:apis:eBLBaseComponents">
        <RecipientUserID>test_user</RecipientUserID>
        <TransactionID>123456789</TransactionID>
        <ItemID>987654321</ItemID>
      </GetItemTransactionsResponse>
    XML
  end

  let(:item_listed_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <GetItemListedResponse xmlns="urn:ebay:apis:eBLBaseComponents">
        <RecipientUserID>test_user</RecipientUserID>
        <ItemID>987654321</ItemID>
      </GetItemListedResponse>
    XML
  end

  before do
    # Mock eBay webhook verification credentials
    allow(Rails.application.credentials).to receive(:ebay).and_return(
      double(webhook_verification_token: 'test_verification_token')
    )

    # Mock eBay API sync callbacks to prevent real API calls during factory creation
    allow_any_instance_of(ExternalAccount).to receive(:sync_ebay_inventory_locations).and_return(true)
    allow_any_instance_of(ExternalAccount).to receive(:sync_ebay_business_policies).and_return(true)
  end

  describe 'POST /webhooks/ebay/notifications' do
    context 'with XML transaction notification' do
      it 'processes transaction notification with service' do
        expect(TransactionNotificationHandler).to receive(:new)
          .with(external_account)
          .and_return(double('handler', process: true))

        post '/webhooks/ebay/notifications',
             params: transaction_xml,
             headers: { 'Content-Type' => 'text/xml' }

        expect(response).to have_http_status(:ok)
      end

      it 'handles item listing notifications' do
        post '/webhooks/ebay/notifications',
             params: item_listed_xml,
             headers: { 'Content-Type' => 'text/xml' }

        expect(response).to have_http_status(:ok)
      end

      it 'ignores unknown notification types' do
        unknown_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <UnknownResponse xmlns="urn:ebay:apis:eBLBaseComponents">
            <RecipientUserID>test_user</RecipientUserID>
          </UnknownResponse>
        XML

        post '/webhooks/ebay/notifications',
             params: unknown_xml,
             headers: { 'Content-Type' => 'text/xml' }

        expect(response).to have_http_status(:ok)
      end

      it 'handles missing external account gracefully' do
        missing_user_xml = transaction_xml.gsub('test_user', 'nonexistent_user')

        post '/webhooks/ebay/notifications',
             params: missing_user_xml,
             headers: { 'Content-Type' => 'text/xml' }

        expect(response).to have_http_status(:ok)
      end

      it 'handles malformed XML gracefully' do
        post '/webhooks/ebay/notifications',
             params: '<invalid>xml',
             headers: { 'Content-Type' => 'text/xml' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with JSON notification' do
      let(:json_payload) { { notification: { data: { sellerId: 'test_user' } } }.to_json }

      it 'verifies JSON signature and returns ok' do
        post '/webhooks/ebay/notifications',
             params: json_payload,
             headers: {
               'Content-Type' => 'application/json',
               'X-EBAY-SIGNATURE' => 'test_signature'
             }

        expect(response).to have_http_status(:ok)
      end

      it 'handles missing signature' do
        post '/webhooks/ebay/notifications',
             params: json_payload,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with empty body' do
      it 'returns ok status' do
        post '/webhooks/ebay/notifications'

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /webhooks/ebay/marketplace_account_deletion' do
    it 'returns challenge response for valid verification' do
      get '/webhooks/ebay/marketplace_account_deletion',
          params: { challenge_code: 'test_challenge_123' }

      expect(response).to have_http_status(:ok)

      response_body = JSON.parse(response.body)
      expect(response_body).to have_key('challengeResponse')
      expect(response_body['challengeResponse']).to be_a(String)
      expect(response_body['challengeResponse'].length).to eq(64) # SHA256 hex string
    end

    it 'returns bad request for missing challenge code' do
      get '/webhooks/ebay/marketplace_account_deletion'

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /webhooks/ebay/marketplace_account_deletion' do
    it 'processes account deletion notification' do
      post '/webhooks/ebay/marketplace_account_deletion',
           params: { userId: 'test_user' }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:ok)
    end
  end
end
