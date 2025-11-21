FactoryBot.define do
  factory :condition do
    sequence(:name) { |n| "Condition #{n}" }
    description { "A test condition description" }
    association :account

    trait :with_ebay_mapping do
      ebay_condition { "USED_EXCELLENT" }
    end

    trait :new_condition do
      name { "Brand New" }
      description { "Items in brand new condition" }
      ebay_condition { "NEW" }
    end

    trait :used_condition do
      name { "Good Used" }
      description { "Items in good used condition" }
      ebay_condition { "USED_GOOD" }
    end
  end
end
