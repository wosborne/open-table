class ExternalAccountInventoryUnit < ApplicationRecord
  belongs_to :external_account
  belongs_to :inventory_unit

  validates :external_account_id, uniqueness: { scope: :inventory_unit_id }
  
  before_update :handle_status_change
  before_destroy :remove_from_ebay

  def published?
    marketplace_data&.dig('published') || false
  end

  def listing_id
    marketplace_data&.dig('listing_id')
  end

  def price
    marketplace_data&.dig('price')&.to_f
  end

  def listed_at
    timestamp = marketplace_data&.dig('listed_at')
    timestamp ? Time.parse(timestamp) : nil
  rescue ArgumentError
    nil
  end

  def url
    marketplace_data&.dig('url')
  end

  def status_label
    return 'Not Listed' unless marketplace_data.present?
    published? ? 'Live on eBay' : 'In eBay Inventory'
  end

  def perform_action(action)
    case action
    when 'publish'
      publish_listing
    when 'end'
      end_listing
    when 'relist'
      relist_listing
    when 'archive'
      archive_listing
    else
      { success: false, message: "Unknown action: #{action}" }
    end
  end

  private

  def publish_listing
    update_marketplace_data(
      status: 'active',
      listed_at: Time.current.iso8601,
      price: inventory_unit.variant&.price
    )
    { success: true, message: "Listed on #{external_account.service_name.humanize} successfully!" }
  end

  def end_listing
    update_marketplace_data(status: 'ended')
    { success: true, message: "#{external_account.service_name.humanize} listing ended." }
  end

  def relist_listing
    update_marketplace_data(
      status: 'active',
      listed_at: Time.current.iso8601
    )
    { success: true, message: "Relisted on #{external_account.service_name.humanize}!" }
  end

  def archive_listing
    destroy
    { success: true, message: "#{external_account.service_name.humanize} listing archived." }
  end

  def update_marketplace_data(updates)
    self.marketplace_data = (marketplace_data || {}).merge(updates.stringify_keys)
    save
  end

  def remove_from_ebay
    return unless external_account.service_name == 'ebay'
    
    begin
      api_client = EbayApiClient.new(external_account)
      sku = marketplace_data&.dig('sku') || inventory_unit.variant.sku
      
      # Delete inventory item (this also deletes associated offers)
      delete_result = api_client.delete("/sell/inventory/v1/inventory_item/#{sku}")
      
      if delete_result[:success]
        Rails.logger.info "Successfully removed eBay inventory item: #{sku}"
      elsif ebay_item_not_found?(delete_result)
        Rails.logger.info "eBay inventory item #{sku} already removed or not found - continuing with deletion"
      else
        Rails.logger.error "Failed to remove eBay inventory item #{sku}: #{delete_result[:error]}"
        # Prevent the destruction - throw an error to halt the transaction
        raise "Failed to remove item from eBay: #{delete_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Error removing eBay inventory item: #{e.message}"
      # Re-raise to prevent deletion
      raise e
    end
  end

  def ebay_item_not_found?(result)
    # Check if eBay returned a "not found" error, meaning item is already gone
    result[:status_code] == 404 ||
    result.dig(:detailed_errors)&.any? { |error| error[:error_id] == 25001 } # Item not found error
  end
end