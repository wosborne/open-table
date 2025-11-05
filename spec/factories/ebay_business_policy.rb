FactoryBot.define do
  factory :ebay_business_policy do
    external_account { association :external_account, :ebay }
    sequence(:ebay_policy_id) { |n| "policy_#{n}_#{SecureRandom.hex(4)}" }
    sequence(:name) { |n| "Test Business Policy #{n}" }
    marketplace_id { "EBAY_GB" }
    policy_type { "fulfillment" }

    trait :fulfillment do
      policy_type { "fulfillment" }
      sequence(:name) { |n| "Fulfillment Policy #{n}" }
    end

    trait :payment do
      policy_type { "payment" }
      sequence(:name) { |n| "Payment Policy #{n}" }
    end

    trait :return do
      policy_type { "return" }
      sequence(:name) { |n| "Return Policy #{n}" }
    end

    trait :us_marketplace do
      marketplace_id { "EBAY_US" }
    end

    trait :de_marketplace do
      marketplace_id { "EBAY_DE" }
    end
  end
end
