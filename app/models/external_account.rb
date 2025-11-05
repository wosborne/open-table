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
  after_create :sync_ebay_inventory_locations, if: :ebay?
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

  def sync_ebay_inventory_locations
    return unless ebay?
    
    begin
      ebay_locations = fetch_ebay_inventory_locations
      return if ebay_locations.nil?
      
      process_ebay_locations(ebay_locations)
    rescue => e
      Rails.logger.error "Error synchronizing eBay inventory locations: #{e.message}"
    end
  end

  private


  def fetch_ebay_inventory_locations
    ebay_client = EbayApiClient.new(self)
    response = ebay_client.get_inventory_locations
    
    unless response[:success]
      Rails.logger.error "Failed to fetch eBay inventory locations: #{response[:error]}"
      return nil
    end
    
    response[:data]['locations'] || []
  end

  def process_ebay_locations(ebay_locations)
    ebay_locations.each do |ebay_location|
      location_key = ebay_location['merchantLocationKey']
      
      next if location_exists_locally?(location_key)
      
      create_location_from_ebay_data(ebay_location)
    end
  end

  def location_exists_locally?(location_key)
    account.locations.exists?(ebay_merchant_location_key: location_key)
  end

  def create_location_from_ebay_data(ebay_location)
    location_name = ebay_location['name']
    location_address = ebay_location.dig('location', 'address') || {}
    
    new_location = account.locations.build(
      build_location_attributes(ebay_location['merchantLocationKey'], location_name, location_address)
    )
    
    new_location.skip_ebay_sync = true
    
    unless new_location.save
      Rails.logger.error "Failed to create location '#{location_name}': #{new_location.errors.full_messages.join(', ')}"
    end
  end

  def build_location_attributes(location_key, location_name, location_address)
    {
      name: location_name,
      address_line_1: location_address['addressLine1'] || '',
      address_line_2: location_address['addressLine2'],
      city: location_address['city'] || '',
      state: location_address['stateOrProvince'],
      postcode: location_address['postalCode'] || '',
      country: location_address['country'] || 'GB',
      ebay_merchant_location_key: location_key
    }
  end

  def should_create_ebay_location?
    ebay? && saved_change_to_inventory_location_id? && inventory_location_id.present?
  end

  def create_ebay_inventory_location
    return unless inventory_location
    
    unless inventory_location.sync_to_ebay!(self)
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
