class ReturnPoliciesController < ExternalAccountsController
  include EbayPolicyManageable

  def new
    @return_policy = build_policy_model({}, "return")
  end

  def create
    form_params = return_policy_params
    @return_policy = build_policy_model(form_params, "return")

    policy_data = build_ebay_policy_data(form_params)
    create_policy_via_ebay_api(@return_policy, policy_data, :create_return_policy, "returnPolicyId")
  end

  private

  def return_policy_params
    params.require(:ebay_business_policy).permit(
      :name, :marketplace_id, :returns_accepted, :return_period_value,
      :return_period_unit, :refund_method, :return_shipping_cost_payer,
      :return_instructions
    )
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
