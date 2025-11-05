class FulfillmentPoliciesController < ExternalAccountsController
  before_action :find_external_account
  
  def new
    @fulfillment_policy = @external_account.fulfillment_policies.build(policy_type: 'fulfillment')
  end

  def shipping_services
    begin
      ebay_client = EbayApiClient.new(@external_account)
      @services = ebay_client.get_shipping_services
      render turbo_frame: "service-select"
    rescue => e
      Rails.logger.error "Error fetching eBay shipping services: #{e.message}"
      @services = []
      render turbo_frame: "service-select"
    end
  end

  def create
    form_params = fulfillment_policy_params
    
    # Only pass attributes that exist on the model
    model_params = form_params.slice(:name, :marketplace_id).merge(policy_type: 'fulfillment')
    @fulfillment_policy = @external_account.fulfillment_policies.build(model_params)
    
    begin
      # Build policy data for eBay API using all form parameters
      policy_data = build_ebay_policy_data(form_params)
      
      # Create policy via eBay API
      ebay_client = EbayApiClient.new(@external_account)
      response = ebay_client.create_fulfillment_policy(policy_data)
      
      if response && [200, 201].include?(response.code)
        # Parse response to get eBay policy ID
        response_data = JSON.parse(response.body)
        @fulfillment_policy.ebay_policy_id = response_data['fulfillmentPolicyId']
        
        if @fulfillment_policy.save
          redirect_to account_external_account_path(current_account, @external_account),
                      notice: "Fulfillment policy '#{@fulfillment_policy.name}' created successfully!"
        else
          render :new, status: :unprocessable_entity
        end
      else
        error_message = if response
          "eBay API error: #{response.code} - #{response.body}"
        else
          "Failed to connect to eBay API"
        end
        Rails.logger.error error_message
        @fulfillment_policy.errors.add(:base, "Failed to create policy on eBay")
        render :new, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error creating fulfillment policy: #{e.message}"
      @fulfillment_policy.errors.add(:base, "Error creating policy: #{e.message}")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def find_external_account
    @external_account = current_account.external_accounts.find(params[:external_account_id])
  end

  def fulfillment_policy_params
    params.require(:fulfillment_policy).permit(
      :name, :marketplace_id, :handling_time, :currency,
      :service_code, :cost, :free_shipping
    )
  end

  def build_ebay_policy_data(policy_params)
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

    # Add shipping option if provided
    if policy_params[:service_code].present?
      shipping_service = {
        shippingServiceCode: policy_params[:service_code],
        freeShipping: policy_params[:free_shipping] == "1"
      }
      
      unless policy_params[:free_shipping] == "1"
        if policy_params[:cost].present?
          shipping_service[:shippingCost] = {
            value: policy_params[:cost].to_s,
            currency: policy_params[:currency] || "GBP"
          }
        end
      end
      
      shipping_option = {
        optionType: "DOMESTIC",
        costType: "FLAT_RATE",
        shippingServices: [shipping_service]
      }
      
      policy_data[:shippingOptions] << shipping_option
    end

    policy_data
  end
end
