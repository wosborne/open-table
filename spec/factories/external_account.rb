FactoryBot.define do
  factory :external_account do
    account { association :account }
    service_name { "shopify" }
    api_token { "test_token" }
    domain { "test-shop.myshopify.com" }

    trait :ebay do
      service_name { "ebay" }
      api_token { "ebay_access_token" }
      refresh_token { "ebay_refresh_token" }
      domain { nil }
    end
  end
end
