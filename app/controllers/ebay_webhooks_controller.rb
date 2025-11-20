class EbayWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :verify_ebay_webhook

  def notifications
    body = request.raw_post

    if body.present?
      # Verify signature for JSON notifications
      if request.content_type&.include?("application/json")
        unless verify_json_signature(body, request)
          head :unauthorized and return
        end
      end

      # Extract notification data and queue processing
      if request.content_type&.include?("application/json")
        process_json_webhook(body)
      else
        process_xml_webhook(body)
      end
    end

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
        endpoint = request.url.split("?").first # Remove query parameters from URL

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

  def process_json_webhook(json_body)
    # Only handling XML transaction notifications for now
  end

  def process_xml_webhook(xml_body)
    notification_type = extract_notification_type(xml_body)
    recipient_user_id = extract_recipient_user_id(xml_body)

    unless recipient_user_id
      Rails.logger.error "eBay webhook: No recipient_user_id found"
      return
    end

    # Find the external account by eBay username
    external_account = ExternalAccount.find_by(service_name: "ebay", ebay_username: recipient_user_id)

    unless external_account
      Rails.logger.error "eBay webhook: No external account found for ebay_username: #{recipient_user_id}"
      return
    end

    case notification_type
    when "ItemTransactions"
      TransactionNotificationHandler.new(external_account).process(xml_body)
    when "ItemListed", "ItemRevised", "ItemClosed", "ItemExtended", "ItemSuspended", "ItemUnsold", "ItemOutOfStock", "EndOfAuction"
      # TODO: Handle other notification types if needed
      Rails.logger.info "eBay webhook: Received #{notification_type} notification for #{recipient_user_id}"
    else
      Rails.logger.info "eBay webhook: Unknown notification type: #{notification_type}"
    end
  end

  def extract_notification_type(xml_body)
    if match = xml_body.match(/<(\w+)Response.*?xmlns=/)
      match[1].gsub("Get", "").gsub("Response", "")
    else
      "Unknown"
    end
  end

  def extract_transaction_id(xml_body)
    if match = xml_body.match(/<TransactionID[^>]*>([^<]+)<\/TransactionID>/)
      match[1]
    end
  end

  def extract_item_id(xml_body)
    if match = xml_body.match(/<ItemID[^>]*>([^<]+)<\/ItemID>/)
      match[1]
    end
  end

  def extract_recipient_user_id(xml_body)
    if match = xml_body.match(/<RecipientUserID[^>]*>([^<]+)<\/RecipientUserID>/)
      match[1]
    end
  end

  def find_external_account_from_json(parsed_json)
    seller_id = parsed_json.dig("notification", "data", "sellerId") ||
                parsed_json.dig("notification", "data", "sellerUsername") ||
                parsed_json.dig("notification", "data", "seller", "username")

    if seller_id
      ExternalAccount.where(service_name: "ebay", ebay_username: seller_id).first
    else
      ExternalAccount.where(service_name: "ebay").first
    end
  end

  def find_external_account_from_xml(xml_body)
    if match = xml_body.match(/<RecipientUserID[^>]*>([^<]+)<\/RecipientUserID>/)
      ebay_user_id = match[1]
      ExternalAccount.where(service_name: "ebay", ebay_username: ebay_user_id).first
    else
      ExternalAccount.where(service_name: "ebay").first
    end
  end

  def verify_json_signature(body, request)
    signature = request.headers["X-EBAY-SIGNATURE"]
    return false unless signature.present?

    # TODO: Implement proper ECC signature verification
    # For now, accept all signatures during development
    true
  end

  def verify_ebay_webhook
    true
  end
end
