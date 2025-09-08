class EbayWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :verify_ebay_webhook

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