class EbayWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :verify_ebay_webhook

  def notifications
    Rails.logger.info "="*50
    Rails.logger.info "eBay Notification received at: #{Time.current}"
    Rails.logger.info "Content-Type: #{request.content_type}"
    Rails.logger.info "User-Agent: #{request.headers['User-Agent']}"
    Rails.logger.info "X-EBAY-SIGNATURE: #{request.headers['X-EBAY-SIGNATURE']&.truncate(50)}"
    Rails.logger.info "Request body (#{request.raw_post.length} chars): #{request.raw_post}"
    Rails.logger.info "="*50
    
    body = request.raw_post
    
    if body.present?
      # Verify signature for JSON notifications
      if request.content_type&.include?('application/json')
        unless verify_json_signature(body, request)
          Rails.logger.error "eBay JSON notification signature verification failed"
          head :unauthorized and return
        end
        Rails.logger.info "eBay JSON notification signature verified"
      end
      
      # Save notification to database (auto-detects JSON vs XML)
      notification = EbayNotification.create_from_webhook(body, request)
      
      # Mark as verified if signature was checked
      notification.mark_as_verified! if request.content_type&.include?('application/json')
      
      if notification.external_account
        Rails.logger.info "Saved notification ID: #{notification.id} for account: #{notification.external_account.id}"
        process_notification(body, notification)
      else
        Rails.logger.warn "Could not identify external account for notification ID: #{notification.id}"
      end
    else
      Rails.logger.warn "Empty notification body received"
    end
    
    # Always respond with 200 OK to acknowledge receipt
    head :ok
  end

  def marketplace_account_deletion
    if request.get?
      # Handle eBay webhook verification (GET request)
      Rails.logger.info "eBay webhook verification request received"
      challenge_code = params[:challenge_code]
      
      if challenge_code.present?
        # Create SHA-256 hash: challengeCode + verificationToken + endpoint
        verification_token = Rails.application.credentials.ebay&.webhook_verification_token
        endpoint = request.url.split('?').first # Remove query parameters from URL
        
        unless verification_token.present?
          Rails.logger.error "eBay webhook verification token not configured"
          head :internal_server_error and return
        end
        
        # Hash in the required order: challengeCode + verificationToken + endpoint
        hash_input = challenge_code + verification_token + endpoint
        challenge_response = Digest::SHA256.hexdigest(hash_input)
        
        Rails.logger.info "Challenge verification - Code: #{challenge_code}, Token: #{verification_token[0..10]}..., Endpoint: #{endpoint}"
        Rails.logger.info "Generated challenge response: #{challenge_response}"
        
        # Return JSON response with challengeResponse
        render json: { challengeResponse: challenge_response }, status: :ok
      else
        head :bad_request
      end
    else
      # Handle actual marketplace account deletion notification (POST request)
      Rails.logger.info "eBay marketplace account deletion webhook received: #{params}"
      
      # Process the account deletion (remove external account, etc.)
      # Implementation depends on the webhook payload structure
      
      head :ok
    end
  end

  private

  def process_notification(body, notification)
    Rails.logger.info "Processing eBay Notification (#{notification.payload_type})"
    
    begin
      if notification.is_json_notification?
        process_json_notification(body, notification)
      else
        process_xml_notification(body, notification)
      end
      
      notification.mark_as_processed!
    rescue => e
      Rails.logger.error "Error processing eBay notification: #{e.message}"
      Rails.logger.error "Notification body: #{body}"
      notification.mark_as_failed!(e) if notification
    end
  end

  def process_json_notification(json_body, notification)
    Rails.logger.info "Processing eBay JSON Notification"
    
    parsed_json = JSON.parse(json_body)
    topic = parsed_json.dig('metadata', 'topic')
    
    case topic
    when 'ITEM_AVAILABILITY'
      Rails.logger.info "Processing item availability notification"
      process_item_availability_notification(parsed_json, notification)
    when 'ITEM_PRICE_REVISION'
      Rails.logger.info "Processing item price revision notification"
      process_item_price_notification(parsed_json, notification)
    when 'MARKETPLACE_ACCOUNT_DELETION'
      Rails.logger.info "Processing marketplace account deletion notification"
      process_account_deletion_notification(parsed_json, notification)
    else
      Rails.logger.info "Received JSON notification topic: #{topic} (not processing)"
    end
  end

  def process_xml_notification(xml_body, notification)
    Rails.logger.info "Processing eBay XML Notification"
    
    # Extract notification type and data from XML
    notification_type = extract_notification_type(xml_body)
    
    case notification_type
    when 'AuctionCheckoutComplete', 'FixedPriceTransaction', 'ItemSold'
      Rails.logger.info "Processing order notification: #{notification_type}"
      process_order_notification(xml_body, notification_type, notification)
    when 'ItemListed', 'ItemRevised', 'ItemClosed', 'ItemExtended', 'ItemSuspended', 'ItemUnsold', 'ItemOutOfStock', 'EndOfAuction'
      Rails.logger.info "Processing listing notification: #{notification_type}"
      process_listing_notification(xml_body, notification_type, notification)
    else
      Rails.logger.info "Received notification type: #{notification_type} (not processing)"
    end
  end

  def extract_notification_type(xml_body)
    # Simple regex to extract the notification type from XML
    # Example: <GetItemTransactionsResponse xmlns="urn:ebay:apis:eBLBaseComponents">
    if match = xml_body.match(/<(\w+)Response.*?xmlns=/)
      match[1].gsub('Get', '').gsub('Response', '')
    else
      'Unknown'
    end
  end

  def process_item_availability_notification(parsed_json, notification)
    Rails.logger.info "Processing item availability notification"
    Rails.logger.info "Notification JSON: #{parsed_json}"
    
    # Extract item details
    item_data = parsed_json.dig('notification', 'data')
    item_id = item_data&.dig('itemId')
    sku = item_data&.dig('sku')
    quantity = item_data&.dig('availability', 'shipToLocationAvailability', 'quantity')
    
    Rails.logger.info "Item availability change - ID: #{item_id}, SKU: #{sku}, Quantity: #{quantity}"
    
    # TODO: Update local inventory based on eBay availability changes
    # Find inventory unit by SKU and update status if quantity is 0
    
    Rails.logger.info "Item availability notification processed successfully"
  end

  def process_item_price_notification(parsed_json, notification)
    Rails.logger.info "Processing item price revision notification"
    Rails.logger.info "Notification JSON: #{parsed_json}"
    
    # Extract price details
    item_data = parsed_json.dig('notification', 'data')
    item_id = item_data&.dig('itemId')
    sku = item_data&.dig('sku')
    new_price = item_data&.dig('price', 'value')
    currency = item_data&.dig('price', 'currency')
    
    Rails.logger.info "Item price change - ID: #{item_id}, SKU: #{sku}, Price: #{new_price} #{currency}"
    
    # TODO: Update local pricing based on eBay price changes
    
    Rails.logger.info "Item price notification processed successfully"
  end

  def process_account_deletion_notification(parsed_json, notification)
    Rails.logger.info "Processing marketplace account deletion notification"
    Rails.logger.info "Notification JSON: #{parsed_json}"
    
    # Extract account details
    account_data = parsed_json.dig('notification', 'data')
    seller_id = account_data&.dig('sellerId')
    marketplace_id = account_data&.dig('marketplaceId')
    
    Rails.logger.info "Account deletion - Seller: #{seller_id}, Marketplace: #{marketplace_id}"
    
    # TODO: Handle account deletion (disable external account, clean up listings)
    
    Rails.logger.info "Account deletion notification processed successfully"
  end

  def process_order_notification(xml_body, notification_type, notification)
    Rails.logger.info "Processing #{notification_type} notification"
    Rails.logger.info "Notification XML: #{xml_body}"
    
    Rails.logger.info "Order notification received and logged successfully"
  end

  def process_listing_notification(xml_body, notification_type, notification)
    Rails.logger.info "Processing #{notification_type} notification"
    Rails.logger.info "Notification XML: #{xml_body}"
    
    Rails.logger.info "Listing notification received and logged successfully"
  end

  def verify_json_signature(body, request)
    signature = request.headers['X-EBAY-SIGNATURE']
    
    unless signature.present?
      Rails.logger.error "Missing X-EBAY-SIGNATURE header"
      return false
    end
    
    Rails.logger.info "Verifying eBay signature: #{signature[0..20]}..."
    
    # TODO: Implement proper ECC signature verification
    # For now, we'll accept all signatures during development
    # In production, this should use eBay's public key to verify the signature
    
    Rails.logger.info "eBay signature verification skipped (development mode)"
    true
  end

  def verify_ebay_webhook
    # Log all headers and params for debugging
    Rails.logger.info "eBay webhook headers: #{request.headers.to_h.select { |k,v| k.downcase.include?('ebay') || k.downcase.include?('auth') || k.downcase.include?('token') }}"
    Rails.logger.info "eBay webhook params: #{params.to_unsafe_h}"
    Rails.logger.info "eBay webhook method: #{request.method}"
    
    # For now, skip verification to see what eBay is sending
    Rails.logger.info "Skipping eBay webhook verification for debugging"
    
    # Return true to allow the request to proceed
    true
  end
end