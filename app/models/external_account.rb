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
  after_update :create_ebay_inventory_location, if: :should_create_ebay_location?

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

  def should_create_ebay_location?
    ebay? && saved_change_to_inventory_location_id? && inventory_location_id.present?
  end

  def create_ebay_inventory_location
    return unless inventory_location

    Rails.logger.info "Syncing inventory location '#{inventory_location.name}' to eBay for external account #{id}"
    
    if inventory_location.sync_to_ebay!(self)
      Rails.logger.info "Successfully synced inventory location '#{inventory_location.name}' to eBay"
    else
      Rails.logger.error "Failed to sync inventory location '#{inventory_location.name}' to eBay"
    end
  rescue => e
    Rails.logger.error "Error syncing inventory location to eBay: #{e.message}"
  end

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
