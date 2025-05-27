FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password = Faker::Internet.password(min_length: 8)
    password { password }
    password_confirmation { password }

    after(:create) do |user|
      account = create(:account)
      create(:account_user, account:, user:)
    end
  end
end
