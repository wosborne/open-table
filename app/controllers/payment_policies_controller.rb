class PaymentPoliciesController < ExternalAccountsController
  before_action :find_external_account
  
  def new
    @payment_policy = @external_account.payment_policies.build(policy_type: 'payment')
  end

  def create
    form_params = payment_policy_params
    
    # Only pass attributes that exist on the model
    model_params = form_params.slice(:name, :marketplace_id).merge(policy_type: 'payment')
    @payment_policy = @external_account.payment_policies.build(model_params)
    
    begin
      # Build policy data for eBay API using all form parameters
      policy_data = build_ebay_policy_data(form_params)
      
      # Create policy via eBay API
      ebay_client = EbayApiClient.new(@external_account)
      response = ebay_client.create_payment_policy(policy_data)
      
      if response && [200, 201].include?(response.code)
        # Parse response to get eBay policy ID
        response_data = JSON.parse(response.body)
        @payment_policy.ebay_policy_id = response_data['paymentPolicyId']
        
        if @payment_policy.save
          redirect_to account_external_account_path(current_account, @external_account),
                      notice: "Payment policy '#{@payment_policy.name}' created successfully!"
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
        @payment_policy.errors.add(:base, "Failed to create policy on eBay")
        render :new, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error creating payment policy: #{e.message}"
      @payment_policy.errors.add(:base, "Error creating policy: #{e.message}")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def find_external_account
    @external_account = current_account.external_accounts.find(params[:external_account_id])
  end

  def payment_policy_params
    params.require(:ebay_business_policy).permit(
      :name, :marketplace_id, :category_type, :immediate_pay
    )
  end

  def build_ebay_policy_data(policy_params)
    policy_data = {
      name: policy_params[:name],
      marketplaceId: policy_params[:marketplace_id] || "EBAY_GB",
      categoryTypes: [
        {
          name: policy_params[:category_type] || "ALL_EXCLUDING_MOTORS_VEHICLES"
        }
      ]
    }

    if policy_params[:immediate_pay] == "1"
      policy_data[:immediatePay] = true
    end

    policy_data
  end
end
