module InventoryUnit::Ebayable
  # extend ActiveSupport::Concern

  # def add_to_ebay_inventory
  #   ebay_account = account.external_accounts.find_by(service_name: 'ebay')

  #   unless ebay_account
  #     return {
  #       success: false,
  #       message: "No eBay account connected to this account."
  #     }
  #   end

  #   ebay_service = EbayService.new(external_account: ebay_account)
  #   product_params = build_ebay_product_params

  #   # First create the inventory item
  #   inventory_result = ebay_service.publish_product(product_params, self)

  #   if inventory_result && inventory_result["success"]
  #     # Now create an unpublished offer for this inventory item
  #     offer_result = ebay_service.create_offer(product_params[:sku], self)

  #     # If offer already exists, that's still a success for our purposes
  #     if offer_result && (offer_result["success"] ||
  #         (offer_result.dig("error", "errors", 0, "errorId") == 25002 &&
  #          offer_result.dig("error", "errors", 0, "message")&.include?("Offer entity already exists")))
  #       result = { "success" => true }
  #     else
  #       result = offer_result
  #     end
  #   else
  #     result = inventory_result
  #   end

  #   if result && result["success"]
  #     # Create the external account inventory unit record
  #     ebay_listing = external_account_inventory_units.create!(
  #       external_account: ebay_account,
  #       marketplace_data: {
  #         published: false,
  #         sku: product_params[:sku],
  #         title: product_params[:title],
  #         created_at: Time.current.iso8601
  #       }
  #     )

  #     {
  #       success: true,
  #       message: "Added to eBay inventory successfully!",
  #       ebay_data: result
  #     }
  #   else
  #     error_message = result&.dig("error", "message") || "Failed to add to eBay inventory"
  #     {
  #       success: false,
  #       message: "eBay API error: #{error_message}"
  #     }
  #   end
  # rescue => e
  #   {
  #     success: false,
  #     message: "eBay API error: #{e.message}"
  #   }
  # end

  # def publish_ebay_offer
  #   ebay_account = account.external_accounts.find_by(service_name: 'ebay')

  #   unless ebay_account
  #     return {
  #       success: false,
  #       message: "No eBay account connected to this account."
  #     }
  #   end

  #   # Find the existing inventory item
  #   ebay_listing = ebay_listing_for_account(account)
  #   unless ebay_listing && !ebay_listing.published?
  #     return {
  #       success: false,
  #       message: "No unpublished eBay inventory item found."
  #     }
  #   end

  #   # Call eBay API to publish the listing
  #   ebay_service = EbayService.new(external_account: ebay_account)
  #   sku = ebay_listing.marketplace_data&.dig('sku') || variant.sku

  #   result = ebay_service.publish_offer(sku)

  #   if result && result["success"]
  #     # Update the listing to published
  #     ebay_listing.update!(
  #       marketplace_data: ebay_listing.marketplace_data.merge(
  #         'published' => true,
  #         'listed_at' => Time.current.iso8601,
  #         'price' => variant.price&.to_s,
  #         'listing_id' => result.dig('listing_id')
  #       )
  #     )

  #     {
  #       success: true,
  #       message: "Published eBay offer successfully!"
  #     }
  #   else
  #     error_details = result&.dig("error")
  #     if error_details.is_a?(Hash)
  #       error_message = error_details["message"] || error_details.inspect
  #     else
  #       error_message = result.inspect
  #     end

  #     {
  #       success: false,
  #       message: "eBay API error: #{error_message}"
  #     }
  #   end
  # rescue => e
  #   {
  #     success: false,
  #     message: "eBay API error: #{e.message}"
  #   }
  # end


  # def delete_ebay_draft
  #   ebay_account = account.external_accounts.find_by(service_name: 'ebay')

  #   unless ebay_account
  #     return {
  #       success: false,
  #       message: "No eBay account connected to this account."
  #     }
  #   end

  #   # Find the existing listing
  #   ebay_listing = ebay_listing_for_account(account)
  #   unless ebay_listing
  #     return {
  #       success: false,
  #       message: "No eBay draft found to delete."
  #     }
  #   end

  #   ebay_service = EbayService.new(external_account: ebay_account)
  #   sku = ebay_listing.marketplace_data&.dig('sku') || variant.sku

  #   result = ebay_service.remove_product(sku)

  #   if result && result["success"]
  #     # Delete the local tracking record
  #     ebay_listing.destroy!

  #     {
  #       success: true,
  #       message: "eBay draft deleted successfully!"
  #     }
  #   else
  #     error_message = result&.dig("error", "message") || "Failed to delete eBay draft"
  #     {
  #       success: false,
  #       message: "eBay API error: #{error_message}"
  #     }
  #   end
  # rescue => e
  #   {
  #     success: false,
  #     message: "eBay API error: #{e.message}"
  #   }
  # end

  # private

  # def build_ebay_product_params
  #   {
  #     sku: variant.sku,
  #     title: variant.product.name,
  #     description: variant.product.description || "#{variant.product.name} - #{variant.sku}",
  #     price: variant.price&.to_s || "0.99"
  #   }
  # end
end
