FactoryBot.define do
  factory :product_option_value do
    product_option
    value { "Value #{SecureRandom.hex(2)}" }
    external_ids { {} }
  end
end
