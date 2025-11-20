FactoryBot.define do
  factory :external_account_product do
    external_account
    product
    status { :active }
    external_id { nil }
  end
end
