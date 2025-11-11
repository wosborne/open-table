class ExternalAccountsController < AccountsController
  skip_before_action :authenticate_user!, only: [ :shopify_callback, :ebay_callback ]
  skip_before_action :find_account, only: [ :shopify_callback, :ebay_callback ]
  skip_before_action :verify_authenticity_token, only: [ :ebay_callback ]

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
      ebay_auth.create_external_account_for(user)
      redirect_to account_tables_path(user.accounts.first), notice: "eBay account connected successfully!"
    else
      redirect_to root_path, alert: "Invalid authentication state"
    end
  rescue => e
    Rails.logger.error "eBay authentication failed: #{e.message}"
    redirect_to root_path, alert: "eBay authentication failed: #{e.message}"
  end


  def show
    @external_account = current_account.external_accounts.find(params[:id])
  end

  def fulfillment_policies
    @external_account = current_account.external_accounts.find(params[:id])
    
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
    @external_account = current_account.external_accounts.find(params[:id])
    
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
    @external_account = current_account.external_accounts.find(params[:id])
    
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
    @external_account = current_account.external_accounts.find(params[:id])
    
    begin
      # Get local locations that are synced to eBay
      local_synced_locations = current_account.locations.where.not(ebay_merchant_location_key: nil)
      
      if local_synced_locations.any?
        # Fetch eBay data for our synced locations
        ebay_client = EbayApiClient.new(@external_account)
        response = ebay_client.get_inventory_locations
        
        if response.success?
          all_ebay_locations = response.data['locations'] || []
          
          # Filter to only show eBay locations that match our local ones
          local_keys = local_synced_locations.pluck(:ebay_merchant_location_key)
          @inventory_locations = all_ebay_locations.select do |ebay_location|
            local_keys.include?(ebay_location['merchantLocationKey'])
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

  def edit
    @external_account = current_account.external_accounts.find(params[:id])
    @locations = current_account.locations
  end

  def update
    @external_account = current_account.external_accounts.find(params[:id])
    @locations = current_account.locations
    
    if @external_account.update(external_account_update_params)
      redirect_to account_external_account_path(current_account, @external_account), 
                  notice: "External account updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def opt_into_business_policies
    @external_account = current_account.external_accounts.find(params[:id])
    ebay_service = EbayService.new(external_account: @external_account)
    
    if ebay_service.opt_into_business_policies
      redirect_to account_external_account_path(current_account, @external_account), 
                  notice: "Successfully opted into business policies!"
    else
      redirect_to account_external_account_path(current_account, @external_account), 
                  alert: "Failed to opt into business policies. You may need to do this manually in your eBay account."
    end
  rescue => e
    Rails.logger.error "Error opting into business policies: #{e.message}"
    redirect_to account_external_account_path(current_account, @external_account), 
                alert: "Error opting into business policies: #{e.message}"
  end

  def create_fulfillment_policy
    @external_account = current_account.external_accounts.find(params[:id])
    ebay_service = EbayService.new(external_account: @external_account)
    
    if ebay_service.create_default_fulfillment_policy
      redirect_to account_external_account_path(current_account, @external_account), 
                  notice: "Default fulfillment policy created successfully!"
    else
      redirect_to account_external_account_path(current_account, @external_account), 
                  alert: "Failed to create fulfillment policy."
    end
  rescue => e
    Rails.logger.error "Error creating fulfillment policy: #{e.message}"
    redirect_to account_external_account_path(current_account, @external_account), 
                alert: "Error creating fulfillment policy: #{e.message}"
  end

  def create_custom_fulfillment_policy
    @external_account = current_account.external_accounts.find(params[:id])
    ebay_service = EbayService.new(external_account: @external_account)
    
    policy_params = fulfillment_policy_params
    
    # Debug: Log the actual parameters received
    Rails.logger.info "Fulfillment policy parameters: #{policy_params.to_json}"
    Rails.logger.info "Domestic cost value: '#{policy_params[:domestic_cost]}'"
    Rails.logger.info "Domestic cost present?: #{policy_params[:domestic_cost].present?}"
    Rails.logger.info "Free shipping value: '#{policy_params[:domestic_free_shipping]}'"
    
    # Build the policy data structure according to eBay API requirements
    # Note: categoryTypes is optional and defaults to ALL_EXCLUDING_MOTORS_VEHICLES if omitted
    policy_data = {
      name: policy_params[:name],
      marketplaceId: policy_params[:marketplace_id] || "EBAY_GB",
      handlingTime: {
        value: policy_params[:handling_time].to_i,
        unit: "DAY"
      },
      localPickup: false,
      shipToLocations: {
        regionIncluded: [
          {
            regionType: "COUNTRY",
            regionId: "GB"
          }
        ]
      },
      shippingOptions: []
    }
    
    # Add description only if provided (eBay doesn't like empty strings)
    if policy_params[:description].present?
      policy_data[:description] = policy_params[:description]
    end
    
    # Add domestic shipping option if provided
    if policy_params[:domestic_service_code].present?
      domestic_service = {
        shippingServiceCode: policy_params[:domestic_service_code],
        freeShipping: policy_params[:domestic_free_shipping] == "1"
      }
      
      # Only add cost if not free shipping
      unless policy_params[:domestic_free_shipping] == "1"
        if policy_params[:domestic_cost].present?
          domestic_service[:shippingCost] = {
            value: policy_params[:domestic_cost].to_s,
            currency: policy_params[:currency] || "GBP"
          }
        end
      end
      
      domestic_option = {
        optionType: "DOMESTIC",
        costType: "FLAT_RATE",
        shippingServices: [domestic_service]
      }
      
      policy_data[:shippingOptions] << domestic_option
    end
    
    # Add international shipping option if provided
    if policy_params[:international_service_code].present?
      international_service = {
        shippingServiceCode: policy_params[:international_service_code],
        freeShipping: policy_params[:international_free_shipping] == "1"
      }
      
      # Only add cost if not free shipping
      unless policy_params[:international_free_shipping] == "1"
        if policy_params[:international_cost].present?
          international_service[:shippingCost] = {
            value: policy_params[:international_cost].to_s,
            currency: policy_params[:currency] || "GBP"
          }
        end
      end
      
      international_option = {
        optionType: "INTERNATIONAL",
        costType: "FLAT_RATE",
        shippingServices: [international_service]
      }
      
      policy_data[:shippingOptions] << international_option
    end
    
    # Log the policy data for debugging
    Rails.logger.info "Creating custom fulfillment policy with data: #{policy_data.to_json}"
    
    response = ebay_service.create_fulfillment_policy(policy_data)
    
    if response && (response.success? || response.code == 201)
      redirect_to account_external_account_path(current_account, @external_account), 
                  notice: "Custom fulfillment policy '#{policy_params[:name]}' created successfully!"
    else
      Rails.logger.error "Custom fulfillment policy creation failed: #{response&.body}"
      redirect_to account_external_account_path(current_account, @external_account), 
                  alert: "Failed to create custom fulfillment policy."
    end
  rescue => e
    Rails.logger.error "Error creating custom fulfillment policy: #{e.message}"
    Rails.logger.error "Policy data was: #{policy_data.to_json}" if defined?(policy_data)
    redirect_to account_external_account_path(current_account, @external_account), 
                alert: "Error creating custom fulfillment policy: #{e.message}"
  end

  def create_inventory_location
    @external_account = current_account.external_accounts.find(params[:id])
    ebay_service = EbayService.new(external_account: @external_account)
    
    ebay_service.create_default_inventory_location
    redirect_to account_external_account_path(current_account, @external_account), 
                notice: "Default inventory location created successfully!"
  rescue => e
    Rails.logger.error "Error creating inventory location: #{e.message}"
    redirect_to account_external_account_path(current_account, @external_account), 
                alert: "Error creating inventory location: #{e.message}"
  end

  def destroy
    @external_account = current_account.external_accounts.find(params[:id])
    @external_account.destroy
    redirect_to edit_account_path(current_account), notice: "External account disconnected successfully!"
  end

  private


  def external_account_params
    params.require(:external_account).permit(:service_name, :domain)
  end

  def external_account_update_params
    params.require(:external_account).permit(:inventory_location_id)
  end

  def fulfillment_policy_params
    params.require(:fulfillment_policy).permit(
      :name, :description, :marketplace_id, :handling_time, :currency,
      :domestic_service_code, :domestic_cost_type, :domestic_cost, :domestic_free_shipping,
      :international_service_code, :international_cost_type, :international_cost, :international_free_shipping
    )
  end
end
