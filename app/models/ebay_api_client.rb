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

  def get_inventory_locations
    get("/sell/inventory/v1/location")
  end

  def create_inventory_location(merchant_location_key, location_data)
    post("/sell/inventory/v1/location/#{merchant_location_key}", location_data)
  end

  def get_shipping_services
    # Try to fetch from eBay API first
    xml_payload = build_get_ebay_details_xml("ShippingServiceDetails")
    response = post_xml("/ws/api.dll", xml_payload)
    
    if response[:success]
      extract_shipping_services(response[:data])
    else
      Rails.logger.error "Failed to fetch shipping services from eBay API: #{response[:error]}"
      Rails.logger.info "Using fallback UK shipping services"
      # Fallback to hardcoded UK domestic shipping services
      get_fallback_uk_shipping_services
    end
  end

  def post_xml(endpoint, xml_payload)
    make_xml_request(:post, endpoint, xml_payload)
  end

  def create_return_policy(policy_data)
    Rails.logger.info "Creating return policy with data: #{policy_data.to_json}"
    
    response = post("/sell/account/v1/return_policy", policy_data)
    
    if response[:success]
      # Convert the response format to match what the controller expects
      mock_response = OpenStruct.new(
        code: response[:status_code],
        body: response[:data].to_json
      )
      Rails.logger.info "Create return policy response: #{mock_response.code} - #{mock_response.body}"
      mock_response
    else
      # Convert error response format
      error_response = OpenStruct.new(
        code: response[:status_code] || 500,
        body: response[:error].is_a?(Hash) ? response[:error].to_json : { error: response[:error] }.to_json
      )
      Rails.logger.error "eBay return policy creation error: #{error_response.code} - #{error_response.body}"
      error_response
    end
  rescue => e
    Rails.logger.error "Unexpected error creating return policy: #{e.message}"
    nil
  end

  def create_payment_policy(policy_data)
    Rails.logger.info "Creating payment policy with data: #{policy_data.to_json}"
    
    response = post("/sell/account/v1/payment_policy", policy_data)
    
    if response[:success]
      # Convert the response format to match what the controller expects
      mock_response = OpenStruct.new(
        code: response[:status_code],
        body: response[:data].to_json
      )
      Rails.logger.info "Create payment policy response: #{mock_response.code} - #{mock_response.body}"
      mock_response
    else
      # Convert error response format
      error_response = OpenStruct.new(
        code: response[:status_code] || 500,
        body: response[:error].is_a?(Hash) ? response[:error].to_json : { error: response[:error] }.to_json
      )
      Rails.logger.error "eBay payment policy creation error: #{error_response.code} - #{error_response.body}"
      error_response
    end
  rescue => e
    Rails.logger.error "Unexpected error creating payment policy: #{e.message}"
    nil
  end

  def create_fulfillment_policy(policy_data)
    Rails.logger.info "Creating fulfillment policy with data: #{policy_data.to_json}"
    
    response = post("/sell/account/v1/fulfillment_policy", policy_data)
    
    if response[:success]
      # Convert the response format to match what the controller expects
      mock_response = OpenStruct.new(
        code: response[:status_code],
        body: response[:data].to_json
      )
      Rails.logger.info "Create fulfillment policy response: #{mock_response.code} - #{mock_response.body}"
      mock_response
    else
      # Convert error response format
      error_response = OpenStruct.new(
        code: response[:status_code] || 500,
        body: response[:error].is_a?(Hash) ? response[:error].to_json : { error: response[:error] }.to_json
      )
      Rails.logger.error "eBay fulfillment policy creation error: #{error_response.code} - #{error_response.body}"
      error_response
    end
  rescue => e
    Rails.logger.error "Unexpected error creating fulfillment policy: #{e.message}"
    nil
  end

  private

  def make_xml_request(method, endpoint, xml_payload)
    attempt_count = 0
    
    begin
      # Trading API uses different base URL
      trading_api_base = "https://api.ebay.com"
      url = "#{trading_api_base}#{endpoint}"
      
      headers = {
        "X-EBAY-API-COMPATIBILITY-LEVEL" => "1193",
        "X-EBAY-API-CALL-NAME" => "GeteBayDetails",
        "X-EBAY-API-SITEID" => "3", # eBay GB
        "X-EBAY-API-IAF-TOKEN" => @access_token, # OAuth token for Trading API
        "Content-Type" => "text/xml; charset=utf-8"
      }
      
      response = RestClient.post(url, xml_payload, headers)
      result = handle_xml_response(response)
      
      # Check if the XML response indicates token expiration and retry if needed
      if !result[:success] && (result[:error]&.include?("Expired IAF token") || result[:error]&.include?("Authorisation token is invalid")) && attempt_count == 0 && can_refresh_token?
        Rails.logger.info "XML API token expired, attempting refresh"
        attempt_count += 1
        
        if refresh_access_token
          Rails.logger.info "XML API token refreshed successfully, retrying request"
          # Update headers with new token and rebuild XML payload with new token
          headers["X-EBAY-API-IAF-TOKEN"] = @access_token
          # Rebuild XML payload with updated token
          xml_payload = xml_payload.gsub(/<eBayAuthToken>.*?<\/eBayAuthToken>/, "<eBayAuthToken>#{@access_token}</eBayAuthToken>")
          response = RestClient.post(url, xml_payload, headers)
          result = handle_xml_response(response)
        else
          Rails.logger.error "XML API token refresh failed"
        end
      end
      
      result
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "eBay Trading API Error: #{e.response.code} - #{e.response.body}"
      handle_xml_error_response(e.response)
    rescue => e
      Rails.logger.error "eBay Trading API Network Error: #{e.message}"
      handle_network_error(e)
    end
  end

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

  def handle_xml_response(response)
    require 'nokogiri'
    
    case response.code
    when 200
      Rails.logger.info "XML Response body: #{response.body}"
      doc = Nokogiri::XML(response.body)
      
      # Check for eBay API errors in XML response  
      ack = doc.at_xpath('//xmlns:Ack', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
      Rails.logger.info "XML Response Ack: #{ack}"
      
      if ack == 'Success' || ack == 'Warning'
        {
          success: true,
          status_code: response.code,
          data: parse_xml_to_hash(doc)
        }
      else
        error_messages = doc.xpath('//xmlns:Errors', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents').map do |error|
          {
            error_code: error.at_xpath('xmlns:ErrorCode', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text,
            short_message: error.at_xpath('xmlns:ShortMessage', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text,
            long_message: error.at_xpath('xmlns:LongMessage', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text,
            severity_code: error.at_xpath('xmlns:SeverityCode', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
          }
        end
        
        Rails.logger.error "XML Response errors: #{error_messages.inspect}"
        
        {
          success: false,
          status_code: response.code,
          error: error_messages.first&.dig(:short_message) || "XML API Error",
          detailed_errors: error_messages
        }
      end
    else
      {
        success: false,
        status_code: response.code,
        error: "Unexpected XML response: #{response.code}",
        raw_response: response.body
      }
    end
  end

  def handle_xml_error_response(response)
    {
      success: false,
      status_code: response.code,
      error: "XML API Error: #{response.code}",
      raw_response: response.body,
      detailed_errors: []
    }
  end

  def parse_xml_to_hash(doc)
    # Convert XML to a hash structure that matches what we expect
    result = {}
    
    # Parse ShippingCarrierDetails with namespace
    shipping_carriers = doc.xpath('//xmlns:ShippingCarrierDetails', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents').map do |carrier|
      {
        'ShippingCarrier' => carrier.at_xpath('xmlns:ShippingCarrier', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text,
        'Description' => carrier.at_xpath('xmlns:Description', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
      }
    end
    result['ShippingCarrierDetails'] = shipping_carriers if shipping_carriers.any?
    
    Rails.logger.info "Parsed shipping carriers: #{shipping_carriers.inspect}"
    
    # Parse ShippingServiceDetails with namespace
    shipping_services = doc.xpath('//xmlns:ShippingServiceDetails', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents').map do |service|
      {
        'ShippingService' => service.at_xpath('xmlns:ShippingService', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text,
        'Description' => service.at_xpath('xmlns:Description', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text,
        'ShippingCarrier' => service.at_xpath('xmlns:ShippingCarrier', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
      }
    end
    result['ShippingServiceDetails'] = shipping_services if shipping_services.any?
    
    result
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
    
    # Check error body for token expiration indicators (JSON APIs)
    error_body = JSON.parse(error.response.body) rescue {}
    error_messages = error_body.dig("errors")&.map { |e| e["message"] }&.join(" ") || ""
    
    # Check for XML API token errors
    if error.response.body.include?("<?xml")
      xml_body = error.response.body
      return true if xml_body.include?("Expired IAF token") || 
                     xml_body.include?("Authorisation token is hard expired") ||
                     xml_body.include?("Invalid IAF token")
    end
    
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

  def build_get_ebay_details_xml(detail_name)
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <GeteBayDetailsRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <RequesterCredentials>
          <eBayAuthToken>#{@access_token}</eBayAuthToken>
        </RequesterCredentials>
        <DetailName>#{detail_name}</DetailName>
        <WarningLevel>High</WarningLevel>
      </GeteBayDetailsRequest>
    XML
  end

  def extract_shipping_services(data)
    services = data['ShippingServiceDetails'] || []
    # Only return domestic UK services
    services.select { |service| 
      service['ShippingService']&.include?('UK_') && 
      !service['ShippingService']&.include?('International')
    }.map do |service|
      {
        value: service['ShippingService'],
        label: service['Description'] || service['ShippingService'],
        carrier: service['ShippingCarrier']
      }
    end.compact
  end

  def get_fallback_uk_shipping_services
    [
      {
        value: 'UK_RoyalMailFirstClassStandard',
        label: 'Royal Mail 1st Class Standard',
        carrier: 'Royal Mail'
      },
      {
        value: 'UK_RoyalMailSecondClassStandard',
        label: 'Royal Mail 2nd Class Standard',
        carrier: 'Royal Mail'
      },
      {
        value: 'UK_RoyalMailSpecialDeliveryNextDay',
        label: 'Royal Mail Special Delivery Next Day',
        carrier: 'Royal Mail'
      },
      {
        value: 'UK_RoyalMailTracked24',
        label: 'Royal Mail Tracked 24',
        carrier: 'Royal Mail'
      },
      {
        value: 'UK_RoyalMailTracked48',
        label: 'Royal Mail Tracked 48',
        carrier: 'Royal Mail'
      },
      {
        value: 'UK_DPDLocalNextDay',
        label: 'DPD Next Day',
        carrier: 'DPD'
      },
      {
        value: 'UK_DPDLocal12Service',
        label: 'DPD 12:00 Service',
        carrier: 'DPD'
      },
      {
        value: 'UK_HermesStandardService',
        label: 'Evri Standard Service',
        carrier: 'Evri'
      },
      {
        value: 'UK_UPSExpressNextDay',
        label: 'UPS Express Next Day',
        carrier: 'UPS'
      },
      {
        value: 'UK_UPSStandardService',
        label: 'UPS Standard Service',
        carrier: 'UPS'
      }
    ]
  end

end