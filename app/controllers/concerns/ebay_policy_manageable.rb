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

  def create_policy_via_ebay_api(policy, policy_data, api_method, policy_id_key)
    ebay_client = EbayApiClient.new(@external_account)
    response = ebay_client.public_send(api_method, policy_data)

    if response && [ 200, 201 ].include?(response.code)
      response_data = JSON.parse(response.body)
      policy.ebay_policy_id = response_data[policy_id_key]

      if policy.save
        redirect_to account_external_account_path(current_account, @external_account),
                    notice: "#{policy.policy_type.humanize} policy '#{policy.name}' created successfully!"
      else
        render :new, status: :unprocessable_entity
      end
    else
      handle_api_error_response(policy, response)
    end
  rescue => e
    handle_api_exception(policy, e)
  end

  def handle_api_error_response(policy, response)
    error_message = if response
      "eBay API error: #{response.code} - #{response.body}"
    else
      "Failed to connect to eBay API"
    end
    Rails.logger.error error_message
    policy.errors.add(:base, "Failed to create policy on eBay")
    render :new, status: :unprocessable_entity
  end

  def handle_api_exception(policy, exception)
    Rails.logger.error "Error creating #{policy.policy_type} policy: #{exception.message}"
    policy.errors.add(:base, "Error creating policy: #{exception.message}")
    render :new, status: :unprocessable_entity
  end

  def build_base_policy_data(params)
    {
      name: params[:name],
      marketplaceId: params[:marketplace_id] || "EBAY_GB"
    }
  end
end
