FactoryBot.define do
  factory :account do
    name { Faker::Company.name }
    slug { Faker::Internet.slug }
  end
end
