class PaymentPoliciesController < ExternalAccountsController
  before_action :set_payment_policy, only: [:show, :edit, :update, :destroy]

  def new
    @payment_policy = current_external_account.payment_policies.build
  end

  def show
  end

  def edit
  end

  def create
    @payment_policy = current_external_account.payment_policies.build(
      payment_policy_params.slice(:name, :marketplace_id)
    )
    @payment_policy.ebay_policy_data = build_ebay_policy_data(payment_policy_params)
    
    if @payment_policy.save
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Payment policy '#{@payment_policy.name}' created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @payment_policy.assign_attributes(payment_policy_params.slice(:name, :marketplace_id))
    @payment_policy.ebay_policy_data = build_ebay_policy_data(payment_policy_params)
    
    if @payment_policy.save
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Payment policy '#{@payment_policy.name}' updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    policy_name = @payment_policy.name

    if @payment_policy.destroy
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Payment policy '#{policy_name}' deleted successfully!"
    else
      redirect_to account_external_account_payment_policy_path(current_account, current_external_account, @payment_policy),
                  alert: "Unable to delete payment policy: #{@payment_policy.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_payment_policy
    @payment_policy = current_external_account.payment_policies.find(params[:id])
  end

  def payment_policy_params
    params.require(:ebay_payment_policy).permit(
      :name, :marketplace_id, :category_type, :immediate_pay
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
