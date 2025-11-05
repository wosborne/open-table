class PaymentPoliciesController < ExternalAccountsController
  include EbayPolicyManageable

  def new
    @payment_policy = build_policy_model({}, "payment")
  end

  def create
    form_params = payment_policy_params
    @payment_policy = build_policy_model(form_params, "payment")

    policy_data = build_ebay_policy_data(form_params)
    create_policy_via_ebay_api(@payment_policy, policy_data, :create_payment_policy, "paymentPolicyId")
  end

  private

  def payment_policy_params
    params.require(:ebay_business_policy).permit(
      :name, :marketplace_id, :category_type, :immediate_pay
    )
  end

  def build_ebay_policy_data(policy_params)
    policy_data = build_base_policy_data(policy_params).merge({
      categoryTypes: [
        {
          name: policy_params[:category_type] || "ALL_EXCLUDING_MOTORS_VEHICLES"
        }
      ]
    })

    if policy_params[:immediate_pay] == "1"
      policy_data[:immediatePay] = true
    end

    policy_data
  end
end
