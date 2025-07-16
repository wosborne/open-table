class ExternalAccount < ApplicationRecord
  SERVICE_NAMES = %w[shopify].freeze
  belongs_to :account

  has_many :external_account_products, dependent: :destroy

  validates :service_name, presence: true, uniqueness: { scope: :account_id }
  validates :service_name, inclusion: { in: SERVICE_NAMES }
  validates :api_token, presence: true

  after_create :register_shopify_webhooks, if: :shopify?

  def shopify?
    service_name == "shopify"
  end

  def title
    service_name.titleize
  end

  private

  def register_shopify_webhooks
    session = ShopifyAPI::Auth::Session.new(
      shop: domain,
      access_token: api_token
    )

    results = ShopifyAPI::Webhooks::Registry.register_all(session: session)

    results.each do |result|
      if result.success
        puts "Successfully registered webhook for topic: #{result.topic}"
      else
        puts "Failed to register webhook for topic: #{result.topic}: #{result.body}"
      end
    end
  end
end
