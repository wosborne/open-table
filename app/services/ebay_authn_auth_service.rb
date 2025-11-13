class EbayAuthnAuthService
  def initialize(external_account)
    @external_account = external_account
    @dev_id = Rails.application.credentials.dig(:ebay, :dev_id)
    @app_id = Rails.application.credentials.dig(:ebay, :client_id) 
    @cert_id = Rails.application.credentials.dig(:ebay, :client_secret)
    @ru_name = "#{Rails.application.credentials.dig(:ebay, :callback_url)}/external_accounts/ebay_authn_auth_callback"
    @api_base_url = Rails.application.credentials.dig(:ebay, :api_base_url)
  end

  def get_session_id
    xml_payload = build_get_session_id_xml
    
    Rails.logger.info "Getting eBay Auth'n'Auth session ID for: #{@external_account.ebay_username}"
    
    response = make_authn_auth_request(xml_payload, "GetSessionID")
    
    if response[:success]
      session_id = extract_session_id(response[:data])
      Rails.logger.info "Successfully retrieved session ID: #{session_id}"
      session_id
    else
      Rails.logger.error "Failed to get session ID: #{response[:error]}"
      nil
    end
  rescue => e
    Rails.logger.error "Error getting session ID: #{e.message}"
    nil
  end

  def get_sign_in_url(session_id)
    return nil unless session_id

    # eBay sign-in URL for Auth'n'Auth flow
    auth_base_url = @api_base_url.gsub("api.", "signin.")
    
    "#{auth_base_url}/ws/eBayISAPI.dll?" +
      "SignIn&" +
      "RuName=#{CGI.escape(@ru_name)}&" +
      "SessID=#{session_id}"
  end

  def fetch_token(session_id)
    return nil unless session_id

    xml_payload = build_fetch_token_xml(session_id)
    
    Rails.logger.info "Fetching eBay Auth'n'Auth token for session: #{session_id}"
    
    response = make_authn_auth_request(xml_payload, "FetchToken")
    
    if response[:success]
      auth_token = extract_auth_token(response[:data])
      
      if auth_token
        # Store the Auth'n'Auth token
        @external_account.update!(ebay_auth_token: auth_token)
        Rails.logger.info "Successfully retrieved and stored Auth'n'Auth token"
        auth_token
      else
        Rails.logger.error "No auth token found in response"
        nil
      end
    else
      Rails.logger.error "Failed to fetch auth token: #{response[:error]}"
      nil
    end
  rescue => e
    Rails.logger.error "Error fetching auth token: #{e.message}"
    nil
  end

  private

  def make_authn_auth_request(xml_payload, call_name)
    trading_api_base = @api_base_url
    url = "#{trading_api_base}/ws/api.dll"

    headers = {
      "X-EBAY-API-COMPATIBILITY-LEVEL" => "1173",
      "X-EBAY-API-CALL-NAME" => call_name,
      "X-EBAY-API-SITEID" => "3", # eBay GB
      "X-EBAY-API-DEV-NAME" => @dev_id,
      "X-EBAY-API-APP-NAME" => @app_id,
      "X-EBAY-API-CERT-NAME" => @cert_id,
      "Content-Type" => "text/xml; charset=utf-8"
    }

    response = RestClient.post(url, xml_payload, headers)
    handle_xml_response(response)
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error "eBay Auth'n'Auth API Error: #{e.response.code} - #{e.response.body}"
    handle_xml_error_response(e.response)
  rescue => e
    Rails.logger.error "eBay Auth'n'Auth API Network Error: #{e.message}"
    { success: false, error: e.message }
  end

  def handle_xml_response(response)
    require "nokogiri"

    case response.code
    when 200
      Rails.logger.info "XML Response body: #{response.body}"
      doc = Nokogiri::XML(response.body)

      # Check for eBay API errors in XML response
      ack = doc.at_xpath("//xmlns:Ack", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
      Rails.logger.info "XML Response Ack: #{ack}"

      if ack == "Success" || ack == "Warning"
        {
          success: true,
          status_code: response.code,
          data: doc
        }
      else
        error_messages = doc.xpath("//xmlns:Errors", "xmlns" => "urn:ebay:apis:eBLBaseComponents").map do |error|
          {
            error_code: error.at_xpath("xmlns:ErrorCode", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text,
            short_message: error.at_xpath("xmlns:ShortMessage", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text,
            long_message: error.at_xpath("xmlns:LongMessage", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
          }
        end

        Rails.logger.error "XML Response errors: #{error_messages.inspect}"

        {
          success: false,
          status_code: response.code,
          error: error_messages.first&.dig(:short_message) || "Auth'n'Auth API Error",
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
      error: "Auth'n'Auth API Error: #{response.code}",
      raw_response: response.body
    }
  end

  def build_get_session_id_xml
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <GetSessionIDRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <RuName>#{@ru_name}</RuName>
        <WarningLevel>High</WarningLevel>
      </GetSessionIDRequest>
    XML
  end

  def build_fetch_token_xml(session_id)
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <FetchTokenRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <SessionID>#{session_id}</SessionID>
        <WarningLevel>High</WarningLevel>
      </FetchTokenRequest>
    XML
  end

  def extract_session_id(doc)
    doc.at_xpath("//xmlns:SessionID", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
  end

  def extract_auth_token(doc)
    doc.at_xpath("//xmlns:eBayAuthToken", "xmlns" => "urn:ebay:apis:eBLBaseComponents")&.text
  end
end