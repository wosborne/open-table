class EbayApiClient
  attr_reader :external_account, :api_base_url, :access_token

  def initialize(external_account)
    @external_account = external_account
    @api_base_url = Rails.application.credentials.dig(:ebay, :api_base_url)
    @access_token = external_account.api_token
    @client_id = Rails.application.credentials.dig(:ebay, :client_id)
    @client_secret = Rails.application.credentials.dig(:ebay, :client_secret)
    @token_url = Rails.application.credentials.dig(:ebay, :token_url)
  end

  def put(endpoint, payload)
    make_request(:put, endpoint, payload)
  end

  def post(endpoint, payload = {})
    make_request(:post, endpoint, payload)
  end

  def get(endpoint, params = {})
    make_request(:get, endpoint, nil, params)
  end

  def delete(endpoint)
    make_request(:delete, endpoint)
  end

  private

  def make_request(method, endpoint, payload = nil, params = {})
    with_token_refresh do
      url = "#{@api_base_url}#{endpoint}"
      headers = standard_headers
      
      response = case method
      when :put
        RestClient.put(url, payload&.to_json, headers)
      when :post
        RestClient.post(url, payload&.to_json, headers)
      when :get
        url_with_params = params.any? ? "#{url}?#{params.to_query}" : url
        RestClient.get(url_with_params, headers)
      when :delete
        RestClient.delete(url, headers)
      end
      handle_success_response(response)
    end
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error "eBay API Error: #{e.response.code} - #{e.response.body}"
    handle_error_response(e.response)
  rescue => e
    Rails.logger.error "eBay API Network Error: #{e.message}"
    handle_network_error(e)
  end

  def handle_success_response(response)
    case response.code
    when 200, 201
      parsed_body = JSON.parse(response.body)
      {
        success: true,
        status_code: response.code,
        data: parsed_body
      }
    when 204
      {
        success: true,
        status_code: response.code,
        data: nil
      }
    else
      {
        success: false,
        status_code: response.code,
        error: "Unexpected success response: #{response.code}",
        raw_response: response.body
      }
    end
  end

  def handle_error_response(response)
    error_data = JSON.parse(response.body) rescue {}
    
    {
      success: false,
      status_code: response.code,
      error: error_data,
      detailed_errors: parse_ebay_errors(error_data)
    }
  end

  def handle_network_error(error)
    {
      success: false,
      status_code: nil,
      error: error.message,
      error_type: "network_error",
      detailed_errors: []
    }
  end

  def parse_ebay_errors(error_data)
    return [] unless error_data.dig("errors").is_a?(Array)
    
    error_data["errors"].map do |error|
      {
        error_id: error["errorId"],
        domain: error["domain"],
        subdomain: error["subdomain"],
        category: error["category"],
        message: error["message"],
        long_message: error["longMessage"],
        parameters: error["parameters"] || [],
        severity: categorize_error_severity(error["errorId"])
      }
    end
  end


  def categorize_error_severity(error_id)
    case error_id
    when 1001, 1015
      "critical" # Auth/rate limit issues
    when 25007, 25002
      "high" # Missing required data
    when 25700
      "low" # Already exists errors
    else
      "medium"
    end
  end

  def standard_headers
    {
      "Authorization" => "Bearer #{@access_token}",
      "Content-Type" => "application/json",
      "Content-Language" => "en-GB",
      "Accept" => "application/json"
    }
  end

  def with_token_refresh(&block)
    attempt_count = 0
    
    begin
      yield
    rescue RestClient::ExceptionWithResponse => e
      if token_expired?(e) && attempt_count == 0 && can_refresh_token?
        Rails.logger.info "eBay token expired, attempting refresh"
        attempt_count += 1
        
        if refresh_access_token
          Rails.logger.info "eBay token refreshed successfully, retrying request"
          retry
        else
          Rails.logger.error "eBay token refresh failed"
          raise
        end
      else
        raise
      end
    end
  end

  def token_expired?(error)
    return false unless error.is_a?(RestClient::ExceptionWithResponse)
    return true if error.response.code == 401
    
    # Check error body for token expiration indicators
    error_body = JSON.parse(error.response.body) rescue {}
    error_messages = error_body.dig("errors")&.map { |e| e["message"] }&.join(" ") || ""
    
    error_messages.downcase.include?("token") || 
    error_messages.downcase.include?("unauthorized") ||
    error_messages.downcase.include?("expired")
  end

  def can_refresh_token?
    @external_account.refresh_token.present?
  end

  def refresh_access_token
    return false unless can_refresh_token?

    begin
      response = RestClient.post(
        @token_url,
        {
          grant_type: "refresh_token",
          refresh_token: @external_account.refresh_token
        },
        {
          "Authorization" => "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}",
          "Content-Type" => "application/x-www-form-urlencoded"
        }
      )
      
      token_response = JSON.parse(response.body)
      
      if token_response && token_response['access_token']
        # Update the external account with new token
        @external_account.update!(
          api_token: token_response['access_token'],
          refresh_token: token_response['refresh_token'] || @external_account.refresh_token
        )
        @access_token = token_response['access_token']
        
        Rails.logger.info "eBay access token refreshed successfully"
        true
      else
        Rails.logger.error "eBay token refresh response missing access_token"
        false
      end
    rescue => e
      Rails.logger.error "Failed to refresh eBay token: #{e.message}"
      false
    end
  end
end