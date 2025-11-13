class EbayNotificationService
  def initialize(external_account)
    @external_account = external_account
    @client = EbayApiClient.new(external_account)
  end

  def subscribe_to_order_notifications
    Rails.logger.info "Subscribing eBay account to order notifications: #{@external_account.ebay_username}"
    Rails.logger.info "Webhook URL: #{webhook_endpoint_url}"
    
    # First, set Application-level delivery preferences
    app_xml = build_application_preferences_xml
    Rails.logger.info "Setting Application preferences with XML: #{app_xml}"
    app_response = @client.trading_api_call(app_xml)
    
    if app_response[:success]
      Rails.logger.info "Successfully set Application notification preferences"
    else
      Rails.logger.error "Failed to set Application notification preferences: #{app_response[:error]}"
      return false
    end
    
    # Then, set User-level event subscriptions
    user_xml = build_user_preferences_xml
    Rails.logger.info "Setting User preferences with XML: #{user_xml}"
    user_response = @client.trading_api_call(user_xml)
    
    if user_response[:success]
      Rails.logger.info "Successfully set User notification preferences"
      true
    else
      Rails.logger.error "Failed to set User notification preferences: #{user_response[:error]}"
      false
    end
  rescue => e
    Rails.logger.error "Error subscribing to eBay notifications: #{e.message}"
    false
  end

  def get_notification_preferences
    Rails.logger.info "Getting eBay notification preferences for: #{@external_account.ebay_username}"
    
    # Get both Application and User level preferences
    app_xml = build_get_notification_preferences_xml("Application")
    user_xml = build_get_notification_preferences_xml("User")
    
    # Get Application level (webhook URL, general settings)
    app_response = @client.trading_api_call(app_xml)
    app_xml_body = @client.last_raw_xml_response if app_response[:success]
    
    # Get User level (individual event subscriptions)  
    user_response = @client.trading_api_call(user_xml)
    user_xml_body = @client.last_raw_xml_response if user_response[:success]
    
    if app_response[:success] && user_response[:success]
      Rails.logger.info "Successfully retrieved both Application and User notification preferences"
      Rails.logger.info "Application XML: #{app_xml_body}"
      Rails.logger.info "User XML: #{user_xml_body}"
      
      # Return both as a hash instead of trying to merge XML
      {
        application_xml: app_xml_body,
        user_xml: user_xml_body,
        combined: true
      }
    else
      Rails.logger.error "Failed to get eBay notification preferences"
      Rails.logger.error "App response success: #{app_response[:success]}, error: #{app_response[:error]}" if app_response
      Rails.logger.error "User response success: #{user_response[:success]}, error: #{user_response[:error]}" if user_response
      
      # Return user preferences only if app fails but user succeeds
      if user_response[:success]
        Rails.logger.info "Returning user preferences only"
        user_xml_body
      else
        nil
      end
    end
  rescue => e
    Rails.logger.error "Error getting eBay notification preferences: #{e.message}"
    nil
  end

  private

  def build_application_preferences_xml
    webhook_url = webhook_endpoint_url
    
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <SetNotificationPreferencesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <ApplicationDeliveryPreferences>
          <AlertEnable>Enable</AlertEnable>
          <ApplicationEnable>Enable</ApplicationEnable>
          <ApplicationURL>#{webhook_url}</ApplicationURL>
          <DeviceType>Platform</DeviceType>
          <NotificationPayloadType>SOAP12</NotificationPayloadType>
        </ApplicationDeliveryPreferences>
      </SetNotificationPreferencesRequest>
    XML
  end

  def build_user_preferences_xml
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <SetNotificationPreferencesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <UserDeliveryPreferenceArray>
          <NotificationEnable>
            <EventType>FixedPriceTransaction</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>AuctionCheckoutComplete</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemSold</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemListed</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemRevised</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemClosed</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemExtended</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemSuspended</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemUnsold</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemOutOfStock</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>EndOfAuction</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
        </UserDeliveryPreferenceArray>
      </SetNotificationPreferencesRequest>
    XML
  end

  def build_notification_preferences_xml
    webhook_url = webhook_endpoint_url
    
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <SetNotificationPreferencesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <ApplicationDeliveryPreferences>
          <AlertEnable>Enable</AlertEnable>
          <ApplicationEnable>Enable</ApplicationEnable>
          <ApplicationURL>#{webhook_url}</ApplicationURL>
          <DeviceType>Platform</DeviceType>
        </ApplicationDeliveryPreferences>
        <UserDeliveryPreferenceArray>
          <NotificationEnable>
            <EventType>FixedPriceTransaction</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>AuctionCheckoutComplete</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemSold</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemListed</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemRevised</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemClosed</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemExtended</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemSuspended</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemUnsold</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>ItemOutOfStock</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
          <NotificationEnable>
            <EventType>EndOfAuction</EventType>
            <EventEnable>Enable</EventEnable>
          </NotificationEnable>
        </UserDeliveryPreferenceArray>
      </SetNotificationPreferencesRequest>
    XML
  end

  def webhook_endpoint_url
    host = webhook_host
    Rails.application.routes.url_helpers.ebay_webhooks_url(host: host, protocol: 'https')
  end

  def webhook_host
    if Rails.env.production?
      Rails.application.credentials.dig(:app, :production_host) || "your-app.com"
    else
      # Extract host from eBay callback URL
      callback_url = Rails.application.credentials.dig(:ebay, :callback_url)
      if callback_url
        URI.parse(callback_url).host
      else
        "localhost:3000"
      end
    end
  end

  def build_get_notification_preferences_xml(preference_level = "User")
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <GetNotificationPreferencesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <PreferenceLevel>#{preference_level}</PreferenceLevel>
      </GetNotificationPreferencesRequest>
    XML
  end

  def merge_notification_preferences_xml(app_xml, user_xml)
    require 'nokogiri'
    
    # Parse both XML responses
    app_doc = Nokogiri::XML(app_xml)
    user_doc = Nokogiri::XML(user_xml)
    
    # Extract ApplicationDeliveryPreferences from app response
    app_prefs = app_doc.at_xpath("//xmlns:ApplicationDeliveryPreferences", "xmlns" => "urn:ebay:apis:eBLBaseComponents")
    
    # Extract UserDeliveryPreferenceArray from user response  
    user_prefs = user_doc.at_xpath("//xmlns:UserDeliveryPreferenceArray", "xmlns" => "urn:ebay:apis:eBLBaseComponents")
    
    Rails.logger.info "App prefs found: #{app_prefs.present?}"
    Rails.logger.info "User prefs found: #{user_prefs.present?}"
    
    # Create combined response based on app response structure
    combined_doc = app_doc.dup
    
    # Add UserDeliveryPreferenceArray after ApplicationDeliveryPreferences
    if user_prefs && app_prefs
      app_prefs.add_next_sibling(user_prefs.to_s)
      Rails.logger.info "Added user prefs to app response"
    end
    
    result = combined_doc.to_xml
    Rails.logger.info "Final merged XML: #{result}"
    result
  end


end