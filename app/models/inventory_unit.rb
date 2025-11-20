class InventoryUnit < ApplicationRecord
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
    ebay_account = account.external_accounts.find_by(service_name: "ebay")
    return nil unless ebay_account
    ebay_listing(ebay_account)
  end

  def add_to_ebay_inventory
    ebay_account = account.external_accounts.find_by(service_name: "ebay")

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
      "/sell/inventory/v1/inventory_item/#{URI.encode_www_form_component(variant.sku)}",
      inventory_item_data
    )

    unless inventory_result.success?
      error_message = build_user_friendly_error_message("inventory item creation", inventory_result)
      return {
        success: false,
        message: error_message
      }
    end

    # Step 2: Create offer
    offer_data = build_ebay_offer_data(ebay_account)
    offer_result = api_client.post("/sell/inventory/v1/offer", offer_data)

    unless offer_result.success? || offer_already_exists_error?(offer_result)
      error_message = build_user_friendly_error_message("offer creation", offer_result)
      return {
        success: false,
        message: error_message
      }
    end

    # Create the external account inventory unit record
    ebay_listing = external_account_inventory_units.create!(
      external_account: ebay_account,
      marketplace_data: {
        published: false,
        sku: variant.sku,
        title: build_ebay_title,
        created_at: Time.current.iso8601,
        offer_id: offer_result.data&.dig("offerId")
      }
    )

    {
      success: true,
      message: "Added to eBay inventory successfully!",
      ebay_listing: ebay_listing
    }
  rescue => e

    # Let the exception message speak for itself with minimal enhancement
    error_message = case e
    when RestClient::ExceptionWithResponse
      "eBay API error: #{e.message}"
    when Net::TimeoutError, RestClient::RequestTimeout
      ebay_error_config.dig("exceptions", "timeout")
    when RestClient::Unauthorized
      ebay_error_config.dig("exceptions", "unauthorized")
    when SocketError, RestClient::ServerBrokeConnection
      ebay_error_config.dig("exceptions", "connection_error")
    else
      "Unexpected error: #{e.message}"
    end

    {
      success: false,
      message: error_message
    }
  end

  def publish_ebay_offer
    ebay_account = account.external_accounts.find_by(service_name: "ebay")

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
    offer_id = ebay_listing.marketplace_data&.dig("offer_id")

    unless offer_id
      return {
        success: false,
        message: "No offer ID found for this listing."
      }
    end

    publish_result = api_client.post("/sell/inventory/v1/offer/#{offer_id}/publish")

    if publish_result.success?
      ebay_listing.update!(
        marketplace_data: ebay_listing.marketplace_data.merge(
          "published" => true,
          "listed_at" => Time.current.iso8601,
          "price" => variant.price&.to_s,
          "listing_id" => publish_result.data&.dig("listingId")
        )
      )

      {
        success: true,
        message: "Published eBay offer successfully!"
      }
    else
      error_message = build_user_friendly_error_message("offer publishing", publish_result)
      {
        success: false,
        message: error_message
      }
    end
  rescue => e
    {
      success: false,
      message: "eBay API error: #{e.message}"
    }
  end

  def delete_ebay_draft
    ebay_account = account.external_accounts.find_by(service_name: "ebay")

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
    sku = ebay_listing.marketplace_data&.dig("sku") || variant.sku

    delete_result = api_client.delete("/sell/inventory/v1/inventory_item/#{sku}")

    if delete_result.success?
      ebay_listing.destroy!

      {
        success: true,
        message: "eBay draft deleted successfully!"
      }
    else
      error_message = build_user_friendly_error_message("draft deletion", delete_result)
      {
        success: false,
        message: error_message
      }
    end
  rescue => e
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
    policy_client = EbayPolicyClient.new(ebay_account)
    policy_ids = policy_client.get_all_default_policy_ids

    # Get the merchant location key from the inventory unit's location or external account's location
    merchant_location_key = get_merchant_location_key(ebay_account)

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
      merchantLocationKey: merchant_location_key,
      listingPolicies: {
        fulfillmentPolicyId: policy_ids[:fulfillment_policy_id],
        paymentPolicyId: policy_ids[:payment_policy_id],
        returnPolicyId: policy_ids[:return_policy_id]
      }
    }
  end

  def get_merchant_location_key(ebay_account)
    # First try to use the inventory unit's specific location
    if location&.synced_to_ebay?
      return location.ebay_merchant_location_key
    end

    # Fall back to the external account's inventory location
    if ebay_account.inventory_location&.synced_to_ebay?
      return ebay_account.inventory_location.ebay_merchant_location_key
    end

    # Last resort: use "default" but this will likely cause eBay API errors
    Rails.logger.warn "No synced eBay location found for inventory unit #{id}, using 'default'"
    "default"
  end

  def build_ebay_title
    parts = [ variant.product.name ]

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

      aspects[aspect_name] = [ aspect_value ]

      # Workaround: Add both Color and Colour for EBAY_GB marketplace
      if aspect_name.downcase == "color"
        aspects["Colour"] = [ aspect_value ]  # Add British spelling
      elsif aspect_name.downcase == "colour"
        aspects["Color"] = [ aspect_value ]   # Add American spelling
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
    if result.detailed_errors&.any?
      result.detailed_errors.map { |e| e[:message] }.join(", ")
    else
      result.error.to_s
    end
  end

  def build_user_friendly_error_message(operation, api_result)
    # Use eBay's actual error messages when available
    if api_result.detailed_errors&.any?
      main_error = api_result.detailed_errors.first
      ebay_message = main_error[:long_message] || main_error[:message]

      # Check for specific error ID mapping first
      if main_error[:error_id] && ebay_error_config.dig("error_codes", main_error[:error_id])
        error_config = ebay_error_config["error_codes"][main_error[:error_id]]
        enhanced_message = error_config["message"]
        return ebay_message.present? ? "#{ebay_message} #{enhanced_message}" : enhanced_message
      end

      # Fall back to HTTP status code mapping
      if ebay_error_config.dig("http_status_codes", api_result.status_code)
        status_message = ebay_error_config["http_status_codes"][api_result.status_code]["message"]
        return ebay_message.present? ? ebay_message : status_message
      end

      # Use original eBay message or fallback
      ebay_message || build_fallback_error_message(operation, api_result)
    else
      # Fallback when no detailed errors available
      build_fallback_error_message(operation, api_result)
    end
  end


  def build_fallback_error_message(operation, api_result)
    # Use this when no detailed_errors are available
    if api_result.error.present?
      # Try to get message from status code configuration
      if ebay_error_config.dig("http_status_codes", api_result.status_code)
        return ebay_error_config["http_status_codes"][api_result.status_code]["message"]
      end

      # Fall back to generic error handling
      if api_result.error.is_a?(String)
        api_result.error
      else
        operation_name = ebay_error_config.dig("operation_defaults", operation.to_s) || "eBay #{operation}"
        "#{operation_name} failed with status #{api_result.status_code}. Please try again."
      end
    else
      operation_name = ebay_error_config.dig("operation_defaults", operation.to_s) || "eBay #{operation}"
      "#{operation_name} failed with status #{api_result.status_code}. Please try again."
    end
  end

  def offer_already_exists_error?(result)
    return false unless result.detailed_errors&.any?

    result.detailed_errors.any? do |error|
      error[:error_id] == 25002 || error[:message]&.include?("Offer entity already exists")
    end
  end

  def ebay_error_config
    @ebay_error_config ||= YAML.load_file(Rails.root.join("config", "ebay_error_messages.yml"))
  end
end
