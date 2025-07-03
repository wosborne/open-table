FactoryBot.define do
  factory :product do
    name { "Test Product" }
    description { "A test product" }
    account { association :account }
  end
end
