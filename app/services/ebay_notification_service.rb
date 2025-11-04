class EbayNotificationService
  def initialize(external_account)
    @external_account = external_account
    @client = EbayApiClient.new(external_account)
  end

  def subscribe_to_order_notifications
    xml_payload = build_notification_preferences_xml
    
    Rails.logger.info "Subscribing eBay account to order notifications: #{@external_account.ebay_username}"
    
    response = @client.trading_api_call(xml_payload)
    
    if response[:success]
      Rails.logger.info "Successfully subscribed eBay account to notifications"
      true
    else
      Rails.logger.error "Failed to subscribe to eBay notifications: #{response[:error]}"
      false
    end
  rescue => e
    Rails.logger.error "Error subscribing to eBay notifications: #{e.message}"
    false
  end

  private

  def build_notification_preferences_xml
    webhook_url = Rails.application.routes.url_helpers.ebay_webhooks_url(host: webhook_host, protocol: 'https')
    
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <SetNotificationPreferencesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <RequesterCredentials>
          <eBayAuthToken>#{@external_account.api_token}</eBayAuthToken>
        </RequesterCredentials>
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
        </UserDeliveryPreferenceArray>
      </SetNotificationPreferencesRequest>
    XML
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
end