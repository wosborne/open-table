FactoryBot.define do
  factory :product_option do
    product
    name { "Option #{SecureRandom.hex(2)}" }
    external_ids { {} }
  end
end
