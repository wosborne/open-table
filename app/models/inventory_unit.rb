class InventoryUnit < ApplicationRecord
  include Ebayable
  
  TABLE_COLUMNS = attribute_names - [ "account_id" ]

  belongs_to :account
  belongs_to :variant
  belongs_to :location, optional: true
  
  has_many_attached :images
  has_many :external_account_inventory_units, dependent: :destroy
  validates :serial_number, presence: true, uniqueness: true
  enum :status, %w[in_stock sold reserved]


  scope :in_stock, -> { where(status: :in_stock) }

  def ebay_listing(external_account)
    external_account_inventory_units.find_by(external_account: external_account)
  end

  def ebay_listing_for_account(account)
    ebay_account = account.external_accounts.find_by(service_name: 'ebay')
    return nil unless ebay_account
    ebay_listing(ebay_account)
  end

  def add_to_ebay_inventory
    ebay_account = account.external_accounts.find_by(service_name: 'ebay')
    
    unless ebay_account
      return {
        success: false,
        message: "No eBay account connected to this account."
      }
    end

    api_client = EbayApiClient.new(ebay_account)
    
    # Step 1: Create inventory item
    inventory_item_data = build_ebay_inventory_item_data
    inventory_result = api_client.put(
      "/sell/inventory/v1/inventory_item/#{variant.sku}", 
      inventory_item_data
    )
    
    unless inventory_result[:success]
      return {
        success: false,
        message: "Failed to create eBay inventory item: #{format_ebay_error(inventory_result)}"
      }
    end

    # Step 2: Create offer
    offer_data = build_ebay_offer_data(ebay_account)
    offer_result = api_client.post("/sell/inventory/v1/offer", offer_data)
    
    unless offer_result[:success]
      if offer_already_exists_error?(offer_result)
        Rails.logger.info "eBay offer already exists for SKU #{variant.sku}, proceeding"
      else
        return {
          success: false,
          message: "Failed to create eBay offer: #{format_ebay_error(offer_result)}"
        }
      end
    end

    # Create the external account inventory unit record
    ebay_listing = external_account_inventory_units.create!(
      external_account: ebay_account,
      marketplace_data: {
        published: false,
        sku: variant.sku,
        title: build_ebay_title,
        created_at: Time.current.iso8601,
        offer_id: offer_result.dig(:data, 'offerId')
      }
    )
    
    {
      success: true,
      message: "Added to eBay inventory successfully!",
      ebay_listing: ebay_listing
    }
  rescue => e
    Rails.logger.error "eBay inventory creation error: #{e.message}"
    {
      success: false,
      message: "eBay API error: #{e.message}"
    }
  end

  def publish_ebay_offer
    ebay_account = account.external_accounts.find_by(service_name: 'ebay')
    
    unless ebay_account
      return {
        success: false,
        message: "No eBay account connected to this account."
      }
    end

    ebay_listing = ebay_listing_for_account(account)
    unless ebay_listing && !ebay_listing.published?
      return {
        success: false,
        message: "No unpublished eBay inventory item found."
      }
    end

    api_client = EbayApiClient.new(ebay_account)
    offer_id = ebay_listing.marketplace_data&.dig('offer_id')
    
    unless offer_id
      return {
        success: false,
        message: "No offer ID found for this listing."
      }
    end

    publish_result = api_client.post("/sell/inventory/v1/offer/#{offer_id}/publish")
    
    if publish_result[:success]
      ebay_listing.update!(
        marketplace_data: ebay_listing.marketplace_data.merge(
          'published' => true,
          'listed_at' => Time.current.iso8601,
          'price' => variant.price&.to_s,
          'listing_id' => publish_result.dig(:data, 'listingId')
        )
      )
      
      {
        success: true,
        message: "Published eBay offer successfully!"
      }
    else
      {
        success: false,
        message: "Failed to publish eBay offer: #{format_ebay_error(publish_result)}"
      }
    end
  rescue => e
    Rails.logger.error "eBay publish error: #{e.message}"
    {
      success: false,
      message: "eBay API error: #{e.message}"
    }
  end

  def delete_ebay_draft
    ebay_account = account.external_accounts.find_by(service_name: 'ebay')
    
    unless ebay_account
      return {
        success: false,
        message: "No eBay account connected to this account."
      }
    end

    ebay_listing = ebay_listing_for_account(account)
    unless ebay_listing
      return {
        success: false,
        message: "No eBay draft found to delete."
      }
    end

    api_client = EbayApiClient.new(ebay_account)
    sku = ebay_listing.marketplace_data&.dig('sku') || variant.sku
    
    delete_result = api_client.delete("/sell/inventory/v1/inventory_item/#{sku}")
    
    if delete_result[:success]
      ebay_listing.destroy!
      
      {
        success: true,
        message: "eBay draft deleted successfully!"
      }
    else
      {
        success: false,
        message: "Failed to delete eBay draft: #{format_ebay_error(delete_result)}"
      }
    end
  rescue => e
    Rails.logger.error "eBay delete error: #{e.message}"
    {
      success: false,
      message: "eBay API error: #{e.message}"
    }
  end

  private

  def build_ebay_inventory_item_data
    {
      product: {
        title: build_ebay_title,
        description: build_ebay_description,
        aspects: build_ebay_aspects,
        imageUrls: build_ebay_image_urls
      },
      condition: "USED_EXCELLENT",
      availability: {
        shipToLocationAvailability: {
          quantity: 1
        }
      },
      packageWeightAndSize: {
        dimensions: {
          height: 1,
          length: 1,  
          width: 1,
          unit: "CENTIMETER"
        },
        weight: {
          value: 1,
          unit: "KILOGRAM"
        }
      }
    }
  end

  def build_ebay_offer_data(ebay_account)
    policy_client = EbayPolicy.new(ebay_account)
    policy_ids = policy_client.get_all_default_policy_ids
    
    {
      sku: variant.sku,
      marketplaceId: "EBAY_GB",
      format: "FIXED_PRICE",
      pricingSummary: {
        price: {
          value: variant.price.to_s,
          currency: "GBP"
        }
      },
      listingDuration: "GTC",
      categoryId: variant.product.ebay_category_id.to_s,
      merchantLocationKey: "default",
      listingPolicies: {
        fulfillmentPolicyId: policy_ids[:fulfillment_policy_id],
        paymentPolicyId: policy_ids[:payment_policy_id],
        returnPolicyId: policy_ids[:return_policy_id]
      }
    }
  end

  def build_ebay_title
    parts = [variant.product.name]
    
    variant.variant_option_values.includes(:product_option, :product_option_value).each do |vov|
      parts << vov.product_option_value.value
    end
    
    parts.join(" - ")
  end

  def build_ebay_description
    description = variant.product.description.presence || "#{variant.product.name} - #{variant.sku}"
    
    variant_details = variant.variant_option_values.includes(:product_option, :product_option_value).map do |vov|
      "#{vov.product_option.name}: #{vov.product_option_value.value}"
    end
    
    if variant_details.any?
      description += "\n\nVariant Details:\n" + variant_details.join("\n")
    end
    
    description
  end

  def build_ebay_aspects
    aspects = {}
    
    # Start with product's saved eBay aspects (item-level aspects like Brand, Model)
    if variant.product.ebay_aspects.present?
      variant.product.ebay_aspects.each do |name, value|
        # Ensure all values are arrays as eBay expects
        aspects[name] = Array(value)
      end
    end
    
    # Add variant option values (variation-level aspects like Colour, Storage Capacity)
    variant.variant_option_values.includes(:product_option, :product_option_value).each do |vov|
      aspect_name = vov.product_option.name
      aspect_value = vov.product_option_value.value
      
      aspects[aspect_name] = [aspect_value]
      
      # Workaround: Add both Color and Colour for EBAY_GB marketplace
      if aspect_name.downcase == "color"
        aspects["Colour"] = [aspect_value]  # Add British spelling
      elsif aspect_name.downcase == "colour"
        aspects["Color"] = [aspect_value]   # Add American spelling
      end
    end
    
    aspects
  end

  def build_ebay_image_urls
    return [] unless images.attached?
    
    images.map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(image, host: "https://5cb64db96b33.ngrok-free.app")
    end
  end

  def format_ebay_error(result)
    if result[:detailed_errors]&.any?
      result[:detailed_errors].map { |e| e[:message] }.join(", ")
    else
      result[:error].to_s
    end
  end

  def offer_already_exists_error?(result)
    return false unless result[:detailed_errors]&.any?
    
    result[:detailed_errors].any? do |error|
      error[:error_id] == 25002 && 
      error[:message]&.include?("Offer entity already exists")
    end
  end

end
