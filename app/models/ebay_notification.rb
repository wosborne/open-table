class EbayNotification < ApplicationRecord
  belongs_to :external_account
  belongs_to :inventory_unit, optional: true
  belongs_to :order, optional: true

  has_one :account, through: :external_account

  validates :notification_type, presence: true
  validate :raw_data_present

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :failed, -> { where(status: "failed") }
  scope :processed, -> { where(status: "processed") }

  def self.create_from_webhook(body, request)
    if request.content_type&.include?("application/json")
      create_from_json_webhook(body, request)
    else
      create_from_xml_webhook(body, request)
    end
  end

  def self.create_from_json_webhook(json_body, request)
    parsed_json = JSON.parse(json_body)
    notification_type = extract_notification_type_from_json(parsed_json)
    external_account = find_external_account_from_json(parsed_json)

    create!(
      external_account: external_account,
      notification_type: notification_type,
      raw_json: json_body,
      parsed_data: parsed_json,
      topic_id: parsed_json.dig("metadata", "topic"),
      schema_version: parsed_json.dig("metadata", "schemaVersion"),
      event_id: parsed_json.dig("metadata", "eventId"),
      request_method: request.method,
      content_type: request.content_type,
      headers: extract_relevant_headers(request),
      status: "received"
    )
  end

  def self.create_from_xml_webhook(xml_body, request)
    notification_type = extract_notification_type_from_xml(xml_body)
    external_account = find_external_account_from_xml(xml_body)

    create!(
      external_account: external_account,
      notification_type: notification_type,
      raw_xml: xml_body,
      request_method: request.method,
      content_type: request.content_type,
      headers: extract_relevant_headers(request),
      status: "received"
    )
  end

  def mark_as_verified!
    update!(signature_verified: true)
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
    return raw_xml if raw_xml.blank? || raw_xml.length <= length
    "#{raw_xml[0, length]}..."
  end

  def truncated_json(length = 500)
    return raw_json if raw_json.blank? || raw_json.length <= length
    "#{raw_json[0, length]}..."
  end

  def raw_payload
    raw_json.present? ? raw_json : raw_xml
  end

  def payload_type
    raw_json.present? ? "JSON" : "XML"
  end

  def is_json_notification?
    raw_json.present?
  end

  def is_xml_notification?
    raw_xml.present?
  end

  def self.notification_types
    distinct.pluck(:notification_type).compact.sort
  end

  def self.statuses
    %w[received processing processed failed]
  end

  def mark_as_processed!
    update!(status: "processed")
  end

  def mark_as_failed!(error)
    update!(status: "failed", error_message: error.to_s)
  end

  private

  def self.extract_notification_type_from_json(parsed_json)
    # Extract topic from metadata, fallback to eventType
    topic = parsed_json.dig("metadata", "topic")
    event_type = parsed_json.dig("notification", "eventType")

    topic || event_type || "Unknown"
  end

  def self.extract_notification_type_from_xml(xml_body)
    if match = xml_body.match(/<(\w+)Response.*?xmlns=/)
      match[1].gsub("Get", "").gsub("Response", "")
    else
      "Unknown"
    end
  end

  def self.find_external_account_from_json(parsed_json)
    # Extract seller ID from various possible locations in JSON
    seller_id = parsed_json.dig("notification", "data", "sellerId") ||
                parsed_json.dig("notification", "data", "sellerUsername") ||
                parsed_json.dig("notification", "data", "seller", "username")

    if seller_id
      Rails.logger.info "Found seller ID in JSON notification: #{seller_id}"

      # Find external account by eBay username
      external_account = ExternalAccount.where(service_name: "ebay", ebay_username: seller_id).first

      if external_account
        Rails.logger.info "Found matching external account: #{external_account.id}"
        return external_account
      else
        Rails.logger.warn "No external account found for eBay seller ID: #{seller_id}"
      end
    else
      Rails.logger.warn "No seller ID found in JSON notification"
    end

    # Fallback to first eBay account if we can't identify from JSON
    fallback_account = ExternalAccount.where(service_name: "ebay").first
    Rails.logger.info "Using fallback eBay account: #{fallback_account&.id}"
    fallback_account
  end

  def self.find_external_account_from_xml(xml_body)
    # Extract RecipientUserID from the XML to identify the eBay account
    if match = xml_body.match(/<RecipientUserID[^>]*>([^<]+)<\/RecipientUserID>/)
      ebay_user_id = match[1]
      Rails.logger.info "Found RecipientUserID in notification: #{ebay_user_id}"

      # Find external account by eBay username
      external_account = ExternalAccount.where(service_name: "ebay", ebay_username: ebay_user_id).first

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
    fallback_account = ExternalAccount.where(service_name: "ebay").first
    Rails.logger.info "Using fallback eBay account: #{fallback_account&.id}"
    fallback_account
  end

  def self.extract_relevant_headers(request)
    request.headers.to_h.select { |k, v| k.downcase.include?("ebay") || k.downcase.include?("auth") || k.downcase.include?("token") || k.downcase.include?("content") }
  end

  def raw_data_present
    errors.add(:base, "Either raw_xml or raw_json must be present") if raw_xml.blank? && raw_json.blank?
  end
end
