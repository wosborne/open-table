class ExternalAccountInventoryUnit < ApplicationRecord
  belongs_to :external_account
  belongs_to :inventory_unit

  validates :external_account_id, uniqueness: { scope: :inventory_unit_id }

  before_destroy :remove_from_ebay

  def published?
    marketplace_data&.dig("published") || false
  end

  def listing_id
    marketplace_data&.dig("listing_id")
  end

  def price
    marketplace_data&.dig("price")&.to_f
  end

  def listed_at
    timestamp = marketplace_data&.dig("listed_at")
    timestamp ? Time.parse(timestamp) : nil
  rescue ArgumentError
    nil
  end

  def url
    marketplace_data&.dig("url")
  end

  def status_label
    return "Not Listed" unless marketplace_data.present?
    published? ? "Live on eBay" : "In eBay Inventory"
  end

  def end_listing
    return unless external_account.service_name == "ebay"

    begin
      api_client = EbayApiClient.new(external_account)
      offer_id = marketplace_data&.dig("offer_id")

      if offer_id.blank?
        return { success: false, message: "No offer ID found for this listing." }
      end

      # Call eBay API to withdraw the offer
      withdraw_result = api_client.post("/sell/inventory/v1/offer/#{offer_id}/withdraw")

      success = withdraw_result.respond_to?(:success?) ? withdraw_result.success? : withdraw_result[:success]

      if success
        update_marketplace_data(status: "ended", published: false)
        Rails.logger.info "Successfully withdrew eBay offer: #{offer_id}"
        { success: true, message: "#{external_account.service_name.humanize} listing ended." }
      else
        error_msg = withdraw_result.respond_to?(:error) ? withdraw_result.error : withdraw_result[:error]
        Rails.logger.error "Failed to withdraw eBay offer #{offer_id}: #{error_msg}"
        { success: false, message: "Failed to end eBay listing: #{error_msg}" }
      end
    rescue => e
      Rails.logger.error "Error withdrawing eBay offer: #{e.message}"
      { success: false, message: "Error ending eBay listing: #{e.message}" }
    end
  end

  private

  def publish_listing
    update_marketplace_data(
      status: "active",
      listed_at: Time.current.iso8601,
      price: inventory_unit.variant&.price
    )
    { success: true, message: "Listed on #{external_account.service_name.humanize} successfully!" }
  end

  def relist_listing
    update_marketplace_data(
      status: "active",
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
    return unless external_account.service_name == "ebay"

    begin
      api_client = EbayApiClient.new(external_account)
      sku = marketplace_data&.dig("sku") || inventory_unit.variant.sku

      # Delete inventory item (this also deletes associated offers)
      delete_result = api_client.delete("/sell/inventory/v1/inventory_item/#{sku}")

      success = delete_result.respond_to?(:success?) ? delete_result.success? : delete_result[:success]
      error_msg = delete_result.respond_to?(:error) ? delete_result.error : delete_result[:error]

      if success
        Rails.logger.info "Successfully removed eBay inventory item: #{sku}"
      elsif ebay_item_not_found?(delete_result)
        Rails.logger.info "eBay inventory item #{sku} already removed or not found - continuing with deletion"
      else
        Rails.logger.error "Failed to remove eBay inventory item #{sku}: #{error_msg}"
        # Prevent the destruction - throw an error to halt the transaction
        raise "Failed to remove item from eBay: #{error_msg}"
      end
    rescue => e
      Rails.logger.error "Error removing eBay inventory item: #{e.message}"
      # Re-raise to prevent deletion
      raise e
    end
  end

  def ebay_item_not_found?(result)
    # Check if eBay returned a "not found" error, meaning item is already gone
    # Handle both hash format (for tests) and EbayApiResponse objects
    status_code = result.respond_to?(:status_code) ? result.status_code : result[:status_code]
    detailed_errors = result.respond_to?(:detailed_errors) ? result.detailed_errors : result[:detailed_errors]

    status_code == 404 ||
    (detailed_errors&.any? { |error|
      error_id = error.respond_to?(:dig) ? error.dig(:errorId) || error.dig(:error_id) : error[:errorId] || error[:error_id]
      [ 25001, 25710 ].include?(error_id)
    }) == true
  end
end
