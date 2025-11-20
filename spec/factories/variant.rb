FactoryBot.define do
  factory :variant do
    product
    sku { "SKU-#{SecureRandom.hex(4)}" }
    price { 9.99 }
    external_ids { {} }
  end
end
