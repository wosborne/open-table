module InventoryUnit::Ebayable
  extend ActiveSupport::Concern

  def create_ebay_draft
    ebay_account = account.external_accounts.find_by(service_name: 'ebay')
    
    unless ebay_account
      return {
        success: false,
        message: "No eBay account connected to this account."
      }
    end

    ebay_service = EbayService.new(external_account: ebay_account)
    product_params = build_ebay_product_params
    
    result = ebay_service.publish_product(product_params)
    
    if result && result["success"]
      # Create the external account inventory unit record
      ebay_listing = external_account_inventory_units.create!(
        external_account: ebay_account,
        marketplace_data: {
          status: 'draft',
          sku: product_params[:sku],
          title: product_params[:title],
          created_at: Time.current.iso8601
        }
      )
      
      {
        success: true,
        message: "eBay draft created successfully!",
        ebay_data: result
      }
    else
      error_message = result&.dig("error", "message") || "Failed to create eBay draft"
      {
        success: false,
        message: "eBay API error: #{error_message}"
      }
    end
  rescue => e
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

    # Find the existing listing
    ebay_listing = ebay_listing_for_account(account)
    unless ebay_listing
      return {
        success: false,
        message: "No eBay draft found to delete."
      }
    end

    ebay_service = EbayService.new(external_account: ebay_account)
    sku = ebay_listing.marketplace_data&.dig('sku') || variant.sku
    
    result = ebay_service.remove_product(sku)
    
    if result && result["success"]
      # Delete the local tracking record
      ebay_listing.destroy!
      
      {
        success: true,
        message: "eBay draft deleted successfully!"
      }
    else
      error_message = result&.dig("error", "message") || "Failed to delete eBay draft"
      {
        success: false,
        message: "eBay API error: #{error_message}"
      }
    end
  rescue => e
    {
      success: false,
      message: "eBay API error: #{e.message}"
    }
  end

  private

  def build_ebay_product_params
    {
      sku: variant.sku,
      title: variant.product.name,
      description: variant.product.description || "#{variant.product.name} - #{variant.sku}",
      price: variant.price&.to_s || "0.99"
    }
  end
end