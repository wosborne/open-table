FactoryBot.define do
  factory :inventory_unit do
    account { variant&.product&.account || association(:account) }
    variant
    serial_number { "INV-#{SecureRandom.hex(4).upcase}" }
    status { :in_stock }
  end
end
