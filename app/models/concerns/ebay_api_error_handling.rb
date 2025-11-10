module EbayApiErrorHandling
  extend ActiveSupport::Concern

  class EbayApiError < StandardError
    attr_reader :status_code, :error_data, :detailed_errors

    def initialize(message, status_code: nil, error_data: nil, detailed_errors: [])
      super(message)
      @status_code = status_code
      @error_data = error_data
      @detailed_errors = detailed_errors
    end
  end

  class EbayAuthenticationError < EbayApiError; end
  class EbayRateLimitError < EbayApiError; end
  class EbayValidationError < EbayApiError; end
  class EbayNetworkError < EbayApiError; end

  class ApiResult
    attr_reader :data, :status_code, :success

    def initialize(success:, data: nil, status_code: nil)
      @success = success
      @data = data
      @status_code = status_code
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  private


  def handle_api_response(response)
    if response.success?
      ApiResult.new(success: true, data: response.data, status_code: response.status_code)
    else
      raise build_appropriate_exception(response)
    end
  end

  def build_appropriate_exception(response)
    message = extract_user_friendly_message(response)
    status_code = response.status_code
    error_data = response.error
    detailed_errors = response.detailed_errors || []
    
    case status_code
    when 401
      EbayAuthenticationError.new(message, status_code: status_code, error_data: error_data, detailed_errors: detailed_errors)
    when 429
      EbayRateLimitError.new(message, status_code: status_code, error_data: error_data, detailed_errors: detailed_errors)
    when 400, 422
      EbayValidationError.new(message, status_code: status_code, error_data: error_data, detailed_errors: detailed_errors)
    when nil
      EbayNetworkError.new(message, status_code: status_code, error_data: error_data, detailed_errors: detailed_errors)
    else
      EbayApiError.new(message, status_code: status_code, error_data: error_data, detailed_errors: detailed_errors)
    end
  end

  def extract_user_friendly_message(response)
    detailed_errors = response.detailed_errors
    error = response.error
    
    if detailed_errors&.any?
      detailed_errors.first[:message] || detailed_errors.first[:long_message]
    elsif error.is_a?(Hash)
      error["message"] || error.values.first
    else
      error || "An error occurred with the eBay API"
    end
  end

  def convert_to_legacy_response(result)
    OpenStruct.new(
      code: result.status_code,
      body: result.data&.to_json || {}.to_json
    )
  end

  def handle_api_request(raise_on_error: false, &block)
    result = yield
    
    Rails.logger.info "eBay API success: #{result.status_code}"
    
    convert_to_legacy_response(result)
  rescue EbayApiError => e
    if raise_on_error
      raise
    end

    Rails.logger.error "eBay API error: #{e.status_code || 500} - #{e.message}"
    if e.error_data.present?
      Rails.logger.error "eBay API error details: #{e.error_data.inspect}"
    end
    if e.detailed_errors.present?
      Rails.logger.error "eBay API detailed errors: #{e.detailed_errors.inspect}"
    end
    
    EbayApiResponse.new(
      success: false,
      status_code: e.status_code || 500,
      error: e.error_data,
      detailed_errors: e.detailed_errors
    )
  rescue => e
    if raise_on_error
      raise
    end

    Rails.logger.error "Unexpected eBay API error: #{e.message}"
    nil
  end

  def handle_api_request_with_exceptions(&block)
    result = yield
    result
  end
end