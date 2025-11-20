RSpec.configure do |config|
  config.before(:each) do
    # Mock the specific Shopify-related calls that cause real HTTP requests

    # 1. Mock external account webhook registration (main culprit in system tests)
    allow_any_instance_of(ExternalAccount).to receive(:register_shopify_webhooks)

    # 2. Mock Shopify API setup and webhook registry
    allow(ShopifyAPI::Context).to receive(:setup)
    allow(ShopifyAPI::Webhooks::Registry).to receive(:register_all).and_return([])
    allow(ShopifyAPI::Webhooks::Registry).to receive(:process)

    # 3. Mock ShopifyAPI Session creation that might trigger real calls
    allow(ShopifyAPI::Auth::Session).to receive(:new).and_return(
      double('MockSession', shop: 'test.myshopify.com', access_token: 'mock_token')
    )
  end
end
