FactoryBot.define do
  factory :table do
    name { "Table" }

    after(:create) do |table|
      create(:property, table: table, name: "Created at", type: "Properties::TimestampProperty")
      create(:property, table: table, name: "Updated at", type: "Properties::TimestampProperty")
    end
  end
end
