class ReturnPoliciesController < ExternalAccountsController
  before_action :find_external_account
  
  def new
    @return_policy = @external_account.return_policies.build(policy_type: 'return')
  end

  def create
    form_params = return_policy_params
    
    # Only pass attributes that exist on the model
    model_params = form_params.slice(:name, :marketplace_id).merge(policy_type: 'return')
    @return_policy = @external_account.return_policies.build(model_params)
    
    begin
      # Build policy data for eBay API using all form parameters
      policy_data = build_ebay_policy_data(form_params)
      
      # Create policy via eBay API
      ebay_client = EbayApiClient.new(@external_account)
      response = ebay_client.create_return_policy(policy_data)
      
      if response && [200, 201].include?(response.code)
        # Parse response to get eBay policy ID
        response_data = JSON.parse(response.body)
        @return_policy.ebay_policy_id = response_data['returnPolicyId']
        
        if @return_policy.save
          redirect_to account_external_account_path(current_account, @external_account),
                      notice: "Return policy '#{@return_policy.name}' created successfully!"
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
        @return_policy.errors.add(:base, "Failed to create policy on eBay")
        render :new, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error creating return policy: #{e.message}"
      @return_policy.errors.add(:base, "Error creating policy: #{e.message}")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def find_external_account
    @external_account = current_account.external_accounts.find(params[:external_account_id])
  end

  def return_policy_params
    params.require(:ebay_business_policy).permit(
      :name, :marketplace_id, :returns_accepted, :return_period_value, 
      :return_period_unit, :refund_method, :return_shipping_cost_payer,
      :return_instructions
    )
  end

  def build_ebay_policy_data(policy_params)
    policy_data = {
      name: policy_params[:name],
      marketplaceId: policy_params[:marketplace_id] || "EBAY_GB",
      returnsAccepted: policy_params[:returns_accepted] == "true"
    }

    if policy_params[:returns_accepted] == "true"
      policy_data[:returnPeriod] = {
        value: policy_params[:return_period_value].to_i,
        unit: policy_params[:return_period_unit] || "DAY"
      }
      
      policy_data[:refundMethod] = policy_params[:refund_method] || "MONEY_BACK"
      policy_data[:returnShippingCostPayer] = policy_params[:return_shipping_cost_payer] || "BUYER"
      
      if policy_params[:return_instructions].present?
        policy_data[:returnInstructions] = policy_params[:return_instructions]
      end
    end

    policy_data
  end
end
