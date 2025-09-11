FactoryBot.define do
  factory :location do
    name { "MyString" }
    address_line_1 { "MyString" }
    address_line_2 { "MyString" }
    city { "MyString" }
    state { "MyString" }
    postcode { "MyString" }
    country { "MyString" }
    account { nil }
  end
end
