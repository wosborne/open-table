FactoryBot.define do
  factory :gmail do
    association :account
    email { Faker::Internet.email }
    access_token { "ya29.#{Faker::Alphanumeric.alphanumeric(number: 100)}" }
    refresh_token { "1//#{Faker::Alphanumeric.alphanumeric(number: 90)}" }
    expires_at { 1.hour.from_now }
    active { true }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :inactive do
      active { false }
    end

    trait :without_refresh_token do
      refresh_token { nil }
    end
  end
end
