FactoryBot.define do
  factory :notification do
    account
    notifiable { nil }
    external_id { "12345" }
    source { "test_source" }
    notification_type { "test_type" }
    title { "Test Notification" }
    message { "Test message" }
    processed { false }
    read { false }
  end
end
