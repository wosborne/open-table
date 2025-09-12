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

    Rails.logger.info "Creating eBay inventory location 'default' for external account #{id}"
    
    ebay_service = EbayService.new(external_account: self)
    result = ebay_service.create_inventory_location("default", inventory_location)
    
    if result["success"]
      Rails.logger.info "Successfully created eBay inventory location 'default'"
    else
      Rails.logger.error "Failed to create eBay inventory location: #{result}"
    end
  rescue => e
    Rails.logger.error "Error creating eBay inventory location: #{e.message}"
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
