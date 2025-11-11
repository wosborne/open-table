class EbayBusinessPolicy < ApplicationRecord
  CACHE_EXPIRY = 1.hour
  POLICY_TYPE = "unknown" # Default for base class

  belongs_to :external_account

  validates :name, presence: true
  validates :marketplace_id, presence: true

  validates :ebay_policy_id, presence: true, uniqueness: true, if: :persisted?

  attr_accessor :ebay_policy_data

  before_create :create_policy_on_ebay
  before_update :update_policy_on_ebay
  after_create :cache_ebay_policy_data_on_create
  after_update :cache_ebay_policy_data_on_update

  scope :fulfillment, -> { where(type: "EbayFulfillmentPolicy") }
  scope :payment, -> { where(type: "EbayPaymentPolicy") }
  scope :return, -> { where(type: "EbayReturnPolicy") }

  # STI setup
  self.inheritance_column = :type

  def self.policy_class_for(policy_type)
    case policy_type
    when "fulfillment"
      EbayFulfillmentPolicy
    when "payment"
      EbayPaymentPolicy
    when "return"
      EbayReturnPolicy
    else
      self
    end
  end

  def policy_type
    self.class::POLICY_TYPE
  end

  def fulfillment?
    policy_type == "fulfillment"
  end

  def payment?
    policy_type == "payment"
  end

  def return?
    policy_type == "return"
  end

  def ebay_attributes
    return {} unless ebay_policy_id.present?

    cache_key = "ebay_policy_#{ebay_policy_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      begin
        ebay_client = EbayApiClient.new(external_account)

        api_method = "get_#{policy_type}_policy"
        response = ebay_client.public_send(api_method, ebay_policy_id)

        if response.success? && response.data
          response.data
        else
          {}
        end
      rescue => e
        Rails.logger.error "Failed to fetch policy #{ebay_policy_id} from eBay: #{e.message}"
        {}
      end
    end
  end





  private

  def create_policy_on_ebay
    return true unless ebay_policy_data.present?

    ebay_client = EbayApiClient.new(external_account)

    api_method = "create_#{policy_type}_policy"
    response = ebay_client.public_send(api_method, ebay_policy_data)

    if response && [ 200, 201 ].include?(response.code)
      response_data = JSON.parse(response.body)
      policy_id_key = "#{policy_type}PolicyId"

      self.ebay_policy_id = response_data[policy_id_key]

      true
    else
      handle_ebay_error(response)
      throw :abort
    end
  rescue => e
    Rails.logger.error "Error creating #{policy_type} policy on eBay: #{e.message}"
    errors.add(:base, "Error creating policy: #{e.message}")
    throw :abort
  end

  def update_policy_on_ebay
    return true unless ebay_policy_data.present?
    return true unless ebay_policy_id.present?

    ebay_client = EbayApiClient.new(external_account)

    api_method = "update_#{policy_type}_policy"
    response = ebay_client.public_send(api_method, ebay_policy_id, ebay_policy_data)

    if response && [ 200, 204 ].include?(response.code)
      true
    else
      handle_ebay_error(response)
      throw :abort
    end
  rescue => e
    Rails.logger.error "Error updating #{policy_type} policy on eBay: #{e.message}"
    errors.add(:base, "Error updating policy: #{e.message}")
    throw :abort
  end

  def cache_ebay_policy_data_on_create
    refresh_ebay_cache if ebay_policy_id.present?
  end

  def cache_ebay_policy_data_on_update
    refresh_ebay_cache if ebay_policy_id.present?
  end

  def refresh_ebay_cache
    cache_key = "ebay_policy_#{ebay_policy_id}"
    Rails.cache.delete(cache_key)

    # Optionally pre-warm the cache by fetching fresh data
    ebay_attributes
  end

  def handle_ebay_error(response)
    if response
      Rails.logger.error "eBay API error: #{response.code} - #{response.error}"

      if response.body.present?
        begin
          error_data = JSON.parse(response.body)
          if error_data["errors"]&.any?
            error_data["errors"].each do |error|
              message = error["longMessage"] || error["message"] || "eBay API error"
              errors.add(:base, message)
            end
          else
            errors.add(:base, "Failed to sync policy with eBay: #{response.error || 'Unknown error'}")
          end
        rescue JSON::ParserError
          errors.add(:base, "Failed to sync policy with eBay: #{response.error || 'Unknown error'}")
        end
      else
        errors.add(:base, "Failed to sync policy with eBay: #{response.error || 'Unknown error'}")
      end
    else
      errors.add(:base, "Failed to connect to eBay API")
    end
  end
end
