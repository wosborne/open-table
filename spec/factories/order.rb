FactoryBot.define do
  factory :order do
    external_account
    external_id { "123456789" }
    name { "#1001" }
    currency { "USD" }
    total_price { 199.99 }
    external_created_at { Time.current }
    financial_status { "paid" }
    fulfillment_status { nil }
  end
end