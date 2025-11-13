class ExternalAccountsController < AccountsController
  skip_before_action :authenticate_user!, only: [ :shopify_callback, :ebay_callback ]
  skip_before_action :find_account, only: [ :shopify_callback, :ebay_callback ]
  skip_before_action :verify_authenticity_token, only: [ :ebay_callback ]
  before_action :set_external_account, except: [ :new, :create, :shopify_callback, :ebay_callback ]

  def new
    @external_account = ExternalAccount.new
  end

  def create
    begin
      case external_account_params[:service_name]
      when "shopify"
        shopify_auth = ShopifyAuthentication.new
        auth_path = shopify_auth.authentication_path(current_user, external_account_params[:domain])
        redirect_to auth_path, allow_other_host: true
      when "ebay"
        ebay_auth = EbayAuthentication.new
        auth_path = ebay_auth.authentication_path(current_user)
        redirect_to auth_path, allow_other_host: true
      else
        redirect_to new_account_external_account_path(current_account), alert: "Invalid service name"
      end
    rescue => e
      Rails.logger.error "External account creation error: #{e.message}"
      redirect_to new_account_external_account_path(current_account), alert: "Failed to initiate authentication: #{e.message}"
    end
  end

  def shopify_callback
    shopify_auth = ShopifyAuthentication.new(params:)
    state = shopify_auth.decode_state(params["state"])
    user = User.find_by(id: state["user_id"], state_nonce: state["nonce"])

    if user
      shopify_auth.create_external_account_for(user)

      redirect_to account_tables_path(user.accounts.first), notice: "Shopify account connected successfully!"
    else
      redirect_to new_account_external_account_path(user.accounts.first), alert: "User not found"
    end
  end

  def ebay_callback
    ebay_auth = EbayAuthentication.new(params: params)
    state = ebay_auth.decode_state(params["state"])
    user = User.find_by(id: state["user_id"], state_nonce: state["nonce"]) if state

    if user
      external_account = ebay_auth.create_external_account_for(user)
      redirect_to account_external_account_path(user.accounts.first, external_account), notice: "eBay account connected successfully!"
    else
      redirect_to root_path, alert: "Invalid authentication state"
    end
  rescue => e
    Rails.logger.error "eBay authentication failed: #{e.message}"
    redirect_to root_path, alert: "eBay authentication failed: #{e.message}"
  end



  def show
  end

  def fulfillment_policies
    begin
      ebay_client = EbayPolicyClient.new(@external_account)
      @fulfillment_policies = ebay_client.get_fulfillment_policies
    rescue => e
      Rails.logger.error "Failed to fetch eBay fulfillment policies: #{e.message}"
      @fulfillment_policies = []
    end

    @local_fulfillment_policies = @external_account.ebay_business_policies.fulfillment

    render turbo_frame: "fulfillment-policies-frame"
  end

  def payment_policies
    begin
      ebay_client = EbayPolicyClient.new(@external_account)
      @payment_policies = ebay_client.get_payment_policies
    rescue => e
      Rails.logger.error "Failed to fetch eBay payment policies: #{e.message}"
      @payment_policies = []
    end

    @local_payment_policies = @external_account.ebay_business_policies.payment

    render turbo_frame: "payment-policies-frame"
  end

  def return_policies
    begin
      ebay_client = EbayPolicyClient.new(@external_account)
      @return_policies = ebay_client.get_return_policies
    rescue => e
      Rails.logger.error "Failed to fetch eBay return policies: #{e.message}"
      @return_policies = []
    end

    @local_return_policies = @external_account.ebay_business_policies.return

    render turbo_frame: "return-policies-frame"
  end

  def inventory_locations
    begin
      # Get local locations that are synced to eBay
      local_synced_locations = current_account.locations.where.not(ebay_merchant_location_key: nil)

      if local_synced_locations.any?
        # Fetch eBay data for our synced locations
        ebay_client = EbayApiClient.new(@external_account)
        response = ebay_client.get_inventory_locations

        if response.success?
          all_ebay_locations = response.data["locations"] || []

          # Filter to only show eBay locations that match our local ones
          local_keys = local_synced_locations.pluck(:ebay_merchant_location_key)
          @inventory_locations = all_ebay_locations.select do |ebay_location|
            local_keys.include?(ebay_location["merchantLocationKey"])
          end

          Rails.logger.info "Filtered eBay inventory locations: #{@inventory_locations.inspect}"
        else
          Rails.logger.error "Failed to fetch eBay inventory locations: #{response.error}"
          @inventory_locations = []
        end
      else
        @inventory_locations = []
      end
    rescue => e
      Rails.logger.error "Failed to fetch eBay inventory locations: #{e.message}"
      @inventory_locations = []
    end

    render turbo_frame: "inventory-locations-frame"
  end

  def notification_preferences
    begin
      notification_service = EbayNotificationService.new(@external_account)
      response_xml = notification_service.get_notification_preferences
      
      Rails.logger.info "Controller received response_xml: #{response_xml.inspect}"

      if response_xml.present?
        if response_xml.is_a?(Hash) && response_xml[:combined]
          # Parse both Application and User XML separately, then combine data
          Rails.logger.info "Parsing Application XML separately"
          app_data = parse_notification_preferences(response_xml[:application_xml])
          Rails.logger.info "App data parsed: #{app_data}"
          
          Rails.logger.info "Parsing User XML separately"  
          user_data = parse_notification_preferences(response_xml[:user_xml])
          Rails.logger.info "User data parsed: #{user_data}"
          
          @notification_data = app_data.merge(enabled_events: user_data[:enabled_events])
        else
          @notification_data = parse_notification_preferences(response_xml)
        end
      else
        @notification_data = { error: "Failed to retrieve notification preferences - empty response" }
      end
    rescue => e
      Rails.logger.error "Failed to fetch eBay notification preferences: #{e.message}"
      @notification_data = { error: e.message }
    end

    render turbo_frame: "notification-preferences-frame"
  end

  def edit
    @locations = current_account.locations
  end

  def update
    @locations = current_account.locations

    if @external_account.update(external_account_update_params)
      redirect_to account_external_account_path(current_account, @external_account),
                  notice: "External account updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end




  def destroy
    @external_account.destroy
    redirect_to edit_account_path(current_account), notice: "External account disconnected successfully!"
  end

  helper_method :current_external_account
  def current_external_account
    @external_account ||= current_account.external_accounts.find(params[:external_account_id] || params[:id])
  end

  private

  def set_external_account
    @external_account = current_account.external_accounts.find(params[:external_account_id] || params[:id])
  end

  def external_account_params
    params.require(:external_account).permit(:service_name, :domain)
  end

  def external_account_update_params
    params.require(:external_account).permit(:inventory_location_id)
  end

  def parse_notification_preferences(xml_response)
    require 'nokogiri'
    
    Rails.logger.info "Parsing XML response: #{xml_response}"
    
    doc = Nokogiri::XML(xml_response)
    
    # Check if the response was successful
    ack_element = doc.at_xpath('//xmlns:Ack', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')
    if ack_element && ack_element.text != 'Success'
      error_message = doc.at_xpath('//xmlns:ShortMessage', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text || 'Unknown error'
      return { error: error_message }
    end
    
    data = {
      webhook_url: nil,
      alert_enabled: false,
      application_enabled: false,
      enabled_events: [],
      payload_type: nil,
      device_type: nil,
      payload_version: nil
    }
    
    # Extract application delivery preferences
    app_prefs = doc.at_xpath('//xmlns:ApplicationDeliveryPreferences', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')
    if app_prefs
      data[:webhook_url] = app_prefs.at_xpath('xmlns:ApplicationURL', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
      data[:alert_enabled] = app_prefs.at_xpath('xmlns:AlertEnable', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text == 'Enable'
      data[:application_enabled] = app_prefs.at_xpath('xmlns:ApplicationEnable', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text == 'Enable'
      data[:payload_type] = app_prefs.at_xpath('xmlns:NotificationPayloadType', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
      data[:device_type] = app_prefs.at_xpath('xmlns:DeviceType', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
      data[:payload_version] = app_prefs.at_xpath('xmlns:PayloadVersion', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
    end
    
    # Extract enabled notification events
    doc.xpath('//xmlns:NotificationEnable', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents').each do |notification|
      event_type = notification.at_xpath('xmlns:EventType', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text
      event_enabled = notification.at_xpath('xmlns:EventEnable', 'xmlns' => 'urn:ebay:apis:eBLBaseComponents')&.text == 'Enable'
      
      if event_type && event_enabled
        data[:enabled_events] << event_type
      end
    end
    
    Rails.logger.info "Parsed notification data: #{data}"
    data
  rescue => e
    Rails.logger.error "Error parsing notification preferences XML: #{e.message}"
    { error: "Failed to parse notification preferences: #{e.message}" }
  end
end
