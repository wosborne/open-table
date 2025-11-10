module EbayPolicyManageable
  extend ActiveSupport::Concern

  included do
    before_action :find_external_account
  end

  private

  def find_external_account
    @external_account = current_account.external_accounts.find(params[:external_account_id])
  end

  def build_policy_model(params, policy_type)
    model_params = params.slice(:name, :marketplace_id).merge(policy_type: policy_type)
    association_name = "#{policy_type}_policies"
    @external_account.public_send(association_name).build(model_params)
  end


  def build_base_policy_data(params)
    {
      name: params[:name],
      marketplaceId: params[:marketplace_id] || "EBAY_GB"
    }
  end

end
