class ReturnPoliciesController < ExternalAccountsController
  before_action :set_return_policy, only: [:show, :edit, :update, :destroy]

  def new
    @return_policy = current_external_account.return_policies.build
  end

  def show
  end

  def edit
  end

  def create
    @return_policy = current_external_account.return_policies.build(
      return_policy_params.slice(:name, :marketplace_id)
    )
    @return_policy.ebay_policy_data = build_ebay_policy_data(return_policy_params)
    
    if @return_policy.save
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Return policy '#{@return_policy.name}' created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @return_policy.assign_attributes(return_policy_params.slice(:name, :marketplace_id))
    @return_policy.ebay_policy_data = build_ebay_policy_data(return_policy_params)
    
    if @return_policy.save
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Return policy '#{@return_policy.name}' updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    policy_name = @return_policy.name

    if @return_policy.destroy
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Return policy '#{policy_name}' deleted successfully!"
    else
      redirect_to account_external_account_return_policy_path(current_account, current_external_account, @return_policy),
                  alert: "Unable to delete return policy: #{@return_policy.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_return_policy
    @return_policy = current_external_account.return_policies.find(params[:id])
  end

  def return_policy_params
    params.require(:ebay_return_policy).permit(
      :name, :marketplace_id, :returns_accepted, :return_period_value,
      :return_period_unit, :refund_method, :return_shipping_cost_payer,
      :return_instructions
    )
  end

  def build_base_policy_data(params)
    {
      name: params[:name],
      marketplaceId: params[:marketplace_id] || "EBAY_GB"
    }
  end

  def build_ebay_policy_data(policy_params)
    policy_data = build_base_policy_data(policy_params).merge({
      returnsAccepted: policy_params[:returns_accepted] == "true"
    })

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
