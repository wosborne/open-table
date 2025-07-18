FactoryBot.define do
  factory :order_line_item do
    order
    external_line_item_id { "987654321" }
    sku { "TEST-SKU" }
    title { "Test Product" }
    quantity { 1 }
    price { 99.99 }
    inventory_unit { nil }
  end
end