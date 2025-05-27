FactoryBot.define do
  factory :account_user do
    association :user
    association :account
  end
end
