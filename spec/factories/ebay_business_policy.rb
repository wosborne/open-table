FactoryBot.define do
  factory :ebay_business_policy do
    external_account { association :external_account, :ebay }
    sequence(:ebay_policy_id) { |n| "policy_#{n}_#{SecureRandom.hex(4)}" }
    sequence(:name) { |n| "Test Business Policy #{n}" }
    marketplace_id { "EBAY_GB" }

    trait :fulfillment do
      sequence(:name) { |n| "Fulfillment Policy #{n}" }
    end

    trait :payment do
      sequence(:name) { |n| "Payment Policy #{n}" }
    end

    trait :return do
      sequence(:name) { |n| "Return Policy #{n}" }
    end

    trait :us_marketplace do
      marketplace_id { "EBAY_US" }
    end

    trait :de_marketplace do
      marketplace_id { "EBAY_DE" }
    end
  end

  factory :ebay_fulfillment_policy, class: "EbayFulfillmentPolicy", parent: :ebay_business_policy do
    type { "EbayFulfillmentPolicy" }
    sequence(:name) { |n| "Fulfillment Policy #{n}" }
  end

  factory :ebay_payment_policy, class: "EbayPaymentPolicy", parent: :ebay_business_policy do
    type { "EbayPaymentPolicy" }
    sequence(:name) { |n| "Payment Policy #{n}" }
  end

  factory :ebay_return_policy, class: "EbayReturnPolicy", parent: :ebay_business_policy do
    type { "EbayReturnPolicy" }
    sequence(:name) { |n| "Return Policy #{n}" }
  end
end
