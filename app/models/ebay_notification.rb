class EbayNotification < ApplicationRecord
  belongs_to :external_account
  belongs_to :inventory_unit, optional: true
  belongs_to :order, optional: true
  
  has_one :account, through: :external_account

  validates :notification_type, presence: true
  validates :raw_xml, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :failed, -> { where(status: 'failed') }
  scope :processed, -> { where(status: 'processed') }
  
  def self.create_from_webhook(xml_body, request)
    notification_type = extract_notification_type_from_xml(xml_body)
    external_account = find_external_account_from_xml(xml_body)
    
    create!(
      external_account: external_account,
      notification_type: notification_type,
      raw_xml: xml_body,
      request_method: request.method,
      content_type: request.content_type,
      headers: extract_relevant_headers(request),
      status: 'received'
    )
  end

  private

  def self.extract_notification_type_from_xml(xml_body)
    if match = xml_body.match(/<(\w+)Response.*?xmlns=/)
      match[1].gsub('Get', '').gsub('Response', '')
    else
      'Unknown'
    end
  end

  def self.find_external_account_from_xml(xml_body)
    # Extract RecipientUserID from the XML to identify the eBay account
    if match = xml_body.match(/<RecipientUserID[^>]*>([^<]+)<\/RecipientUserID>/)
      ebay_user_id = match[1]
      Rails.logger.info "Found RecipientUserID in notification: #{ebay_user_id}"
      
      # Find external account by eBay username
      external_account = ExternalAccount.where(service_name: 'ebay', ebay_username: ebay_user_id).first
      
      if external_account
        Rails.logger.info "Found matching external account: #{external_account.id}"
        return external_account
      else
        Rails.logger.warn "No external account found for eBay user ID: #{ebay_user_id}"
      end
    else
      Rails.logger.warn "No RecipientUserID found in notification XML"
    end
    
    # Fallback to first eBay account if we can't identify from XML
    fallback_account = ExternalAccount.where(service_name: 'ebay').first
    Rails.logger.info "Using fallback eBay account: #{fallback_account&.id}"
    fallback_account
  end

  def self.extract_relevant_headers(request)
    request.headers.to_h.select { |k,v| k.downcase.include?('ebay') || k.downcase.include?('auth') || k.downcase.include?('token') || k.downcase.include?('content') }
  end

  def parsed_data_pretty
    return nil unless parsed_data
    JSON.pretty_generate(parsed_data)
  end

  def headers_pretty
    return nil unless headers
    JSON.pretty_generate(headers)
  end

  def truncated_xml(length = 500)
    return raw_xml if raw_xml.length <= length
    "#{raw_xml[0, length]}..."
  end

  def self.notification_types
    distinct.pluck(:notification_type).compact.sort
  end

  def self.statuses
    %w[received processing processed failed]
  end

  def mark_as_processed!
    update!(status: 'processed')
  end

  def mark_as_failed!(error)
    update!(status: 'failed', error_message: error.to_s)
  end
end