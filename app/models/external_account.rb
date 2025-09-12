class ExternalAccount < ApplicationRecord
  SERVICE_NAMES = %w[shopify ebay].freeze
  belongs_to :account
  belongs_to :inventory_location, class_name: 'Location', optional: true

  has_many :external_account_products
  has_many :external_account_inventory_units, dependent: :destroy

  validates :service_name, presence: true, uniqueness: { scope: :account_id }
  validates :service_name, inclusion: { in: SERVICE_NAMES }
  validates :api_token, presence: true

  after_create :register_shopify_webhooks, if: :shopify?

  before_destroy :destroy_external_account_products

  def shopify?
    service_name == "shopify"
  end

  def ebay?
    service_name == "ebay"
  end

  def title
    service_name.titleize
  end

  private

  def destroy_external_account_products
    external_account_products.each(&:destroy)
  end

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
