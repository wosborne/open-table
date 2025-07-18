FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }
    password_confirmation { "password123" }

    after(:create) do |user|
      account = create(:account)
      create(:account_user, account:, user:)
    end
  end
end
