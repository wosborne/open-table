class EbayWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :verify_ebay_webhook

  def notifications
    Rails.logger.info "eBay Platform Notification received"
    Rails.logger.info "Content-Type: #{request.content_type}"
    Rails.logger.info "Request body: #{request.raw_post}"
    
    # Platform notifications come as SOAP XML
    xml_body = request.raw_post
    
    if xml_body.present?
      # Save notification to database for debugging (will auto-identify account from XML)
      notification = EbayNotification.create_from_webhook(xml_body, request)
      
      if notification.external_account
        Rails.logger.info "Saved notification ID: #{notification.id} for account: #{notification.external_account.username}"
        process_platform_notification(xml_body, notification)
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

  def process_platform_notification(xml_body, notification)
    Rails.logger.info "Processing eBay Platform Notification"
    
    begin
      # Extract notification type and data from XML
      notification_type = extract_notification_type(xml_body)
      
      case notification_type
      when 'AuctionCheckoutComplete', 'FixedPriceTransaction', 'ItemSold'
        Rails.logger.info "Processing order notification: #{notification_type}"
        process_order_notification(xml_body, notification_type, notification)
      when 'ItemListed', 'ItemRevised', 'ItemClosed', 'ItemExtended', 'ItemSuspended'
        Rails.logger.info "Processing listing notification: #{notification_type}"
        process_listing_notification(xml_body, notification_type, notification)
      else
        Rails.logger.info "Received notification type: #{notification_type} (not processing)"
      end
      
      notification.mark_as_processed!
    rescue => e
      Rails.logger.error "Error processing eBay notification: #{e.message}"
      Rails.logger.error "XML body: #{xml_body}"
      notification.mark_as_failed!(e) if notification
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