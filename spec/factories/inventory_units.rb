FactoryBot.define do
  factory :inventory_unit do
    variant { nil }
    serial_number { "MyString" }
    status { 1 }
  end
end
