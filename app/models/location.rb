class Location < ApplicationRecord
  TABLE_COLUMNS = attribute_names - [ "account_id" ]

  belongs_to :account
  has_many :inventory_units, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :address_line_1, presence: true
  validates :city, presence: true
  validates :postcode, presence: true
  validates :country, presence: true

  before_create :sync_to_ebay_on_create

  def full_address
    lines = [address_line_1, address_line_2, city, state, postcode, country].compact
    lines.join(', ')
  end

  def synced_to_ebay?
    ebay_merchant_location_key.present?
  end

  def sync_to_ebay!(external_account)
    return false unless external_account.ebay?
    return true if synced_to_ebay?
    
    # Generate a unique merchant location key
    merchant_key = generate_merchant_location_key
    
    # Build eBay location data
    location_data = build_ebay_location_data
    
    # Create location on eBay
    ebay_client = EbayApiClient.new(external_account)
    response = ebay_client.create_inventory_location(merchant_key, location_data)
    
    if response[:success]
      update!(ebay_merchant_location_key: merchant_key)
      Rails.logger.info "Location '#{name}' synced to eBay with key: #{merchant_key}"
      true
    else
      Rails.logger.error "Failed to sync location '#{name}' to eBay: #{response[:error]}"
      false
    end
  rescue => e
    Rails.logger.error "Error syncing location '#{name}' to eBay: #{e.message}"
    false
  end

  private

  def sync_to_ebay_on_create
    # Find the eBay external account for this location's account
    ebay_account = account.external_accounts.find_by(service_name: 'ebay')
    
    if ebay_account
      # Generate merchant location key before saving
      self.ebay_merchant_location_key = generate_merchant_location_key
      
      # Build eBay location data
      location_data = build_ebay_location_data
      
      # Create location on eBay
      ebay_client = EbayApiClient.new(ebay_account)
      
      # Debug logging
      Rails.logger.info "Creating eBay location with key: #{self.ebay_merchant_location_key}"
      Rails.logger.info "Location data: #{location_data.to_json}"
      
      response = ebay_client.create_inventory_location(self.ebay_merchant_location_key, location_data)
      
      unless response[:success]
        Rails.logger.error "Failed to create eBay location during create: #{response[:error]}"
        self.errors.add(:base, "Failed to create location on eBay: #{response[:error]}")
        raise ActiveRecord::RecordInvalid.new(self)
      end
      
      Rails.logger.info "Location '#{name}' created on eBay with key: #{self.ebay_merchant_location_key}"
    else
      self.errors.add(:base, "eBay account must be connected before creating locations")
      raise ActiveRecord::RecordInvalid.new(self)
    end
  rescue ActiveRecord::RecordInvalid
    raise # Re-raise validation errors
  rescue => e
    Rails.logger.error "Error syncing location to eBay during create: #{e.message}"
    self.errors.add(:base, "Failed to sync location to eBay: #{e.message}")
    raise ActiveRecord::RecordInvalid.new(self)
  end

  def generate_merchant_location_key
    # Generate a unique key based on account and location
    base_key = "#{account.slug}_#{name}".downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_').gsub(/^_|_$/, '')
    
    # Ensure uniqueness by appending timestamp if needed
    if Location.where(ebay_merchant_location_key: base_key).exists?
      "#{base_key}_#{Time.current.to_i}"
    else
      base_key
    end
  end

  def build_ebay_location_data
    address_data = {
      addressLine1: address_line_1,
      city: city,
      postalCode: postcode,
      country: "GB"
    }
    
    # Only add optional fields if they have values
    address_data[:addressLine2] = address_line_2 if address_line_2.present?
    address_data[:stateOrProvince] = state if state.present?
    
    {
      location: {
        address: address_data
      },
      locationTypes: ["WAREHOUSE"],
      name: name,
      merchantLocationStatus: "ENABLED"
    }
  end
end
