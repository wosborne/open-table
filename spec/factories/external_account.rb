FactoryBot.define do
  factory :external_account do
    account { association :account }
    service_name { "shopify" }
    api_token { "test_token" }
    domain { "test-shop.myshopify.com" }
  end
end
