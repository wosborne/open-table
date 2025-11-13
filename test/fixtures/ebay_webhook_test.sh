#!/bin/bash

# eBay Webhook Testing Script
# This script sends test notifications to the local webhook endpoint to verify it's working
#
# HOW TO USE:
# 1. Make sure your Rails server is running: rails server
# 2. Make the script executable: chmod +x test/fixtures/ebay_webhook_test.sh
# 3. Run the script: ./test/fixtures/ebay_webhook_test.sh
# 4. Check Rails logs to see notification processing details

BASE_URL="http://localhost:3000"

echo "🧪 Testing eBay Webhook Endpoints"
echo "================================="

# Test JSON notification
echo "📨 Testing JSON notification..."
curl -X POST "${BASE_URL}/webhooks/ebay/notifications" \
  -H "Content-Type: application/json" \
  -H "X-EBAY-SIGNATURE: test-signature-$(date +%s)" \
  -H "User-Agent: eBay/1.0" \
  -d '{
    "test": "notification",
    "metadata": {
      "topic": "TEST_NOTIFICATION",
      "schemaVersion": "1.0",
      "eventId": "test-event-123"
    },
    "notification": {
      "eventType": "TEST_EVENT",
      "data": {
        "sellerId": "test_seller_123",
        "itemId": "123456789",
        "sku": "TEST-SKU-001"
      }
    }
  }'

echo -e "\n\n📦 Testing XML notification..."
curl -X POST "${BASE_URL}/webhooks/ebay/notifications" \
  -H "Content-Type: application/xml" \
  -H "X-EBAY-SIGNATURE: test-signature-xml-$(date +%s)" \
  -H "User-Agent: eBay/1.0" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<ItemSoldResponse xmlns="urn:ebay:apis:eBLBaseComponents">
  <RecipientUserID>test_seller_123</RecipientUserID>
  <ItemID>123456789</ItemID>
  <SKU>TEST-SKU-XML-001</SKU>
  <Ack>Success</Ack>
</ItemSoldResponse>'

echo -e "\n\n🔄 Testing marketplace account deletion verification (GET)..."
curl -X GET "${BASE_URL}/webhooks/ebay/marketplace_account_deletion?challenge_code=test123"

echo -e "\n\n✅ Webhook tests completed!"
echo "Check your Rails logs to see the notification processing details."
echo ""
echo "To view created notifications in Rails console:"
echo "  rails console"
echo "  EbayNotification.last(5)"