FactoryBot.define do
  factory :external_account_inventory_unit do
    external_account
    inventory_unit
    marketplace_data do
      {
        published: false,
        sku: inventory_unit&.variant&.sku || "TEST-SKU-#{SecureRandom.hex(3)}",
        title: "Test eBay Listing",
        created_at: Time.current.iso8601,
        offer_id: "offer_#{SecureRandom.hex(6)}"
      }
    end

    trait :published do
      marketplace_data do
        {
          published: true,
          sku: inventory_unit&.variant&.sku || "TEST-SKU-#{SecureRandom.hex(3)}",
          title: "Test eBay Listing",
          created_at: 1.hour.ago.iso8601,
          listed_at: Time.current.iso8601,
          price: "99.99",
          offer_id: "offer_#{SecureRandom.hex(6)}",
          listing_id: "listing_#{SecureRandom.hex(8)}"
        }
      end
    end

    trait :with_ebay_account do
      association :external_account, :ebay
    end
  end
end