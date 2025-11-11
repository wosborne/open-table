class PolicyTableComponent < ApplicationComponent
  def initialize(policy_type:, title:, policies:, local_policies:, external_account:, current_account:)
    @policy_type = policy_type
    @title = title
    @policies = policies
    @local_policies = local_policies
    @external_account = external_account
    @current_account = current_account
  end

  private

  attr_reader :policy_type, :title, :policies, :local_policies, :external_account, :current_account

  def frame_id
    "#{policy_type}-policies-frame"
  end

  def detail_column_header
    policy_type == 'fulfillment' ? 'Shipping Service' : 'Payment Method'
  end

  def policy_id_key
    policy_type == 'fulfillment' ? 'fulfillmentPolicyId' : 'paymentPolicyId'
  end

  def detail_value(policy)
    if policy_type == 'fulfillment'
      if policy['shippingOptions']&.any? && policy['shippingOptions'].first['shippingServices']&.any?
        policy['shippingOptions'].first['shippingServices'].first['shippingServiceCode']
      else
        '-'
      end
    else
      if policy['paymentMethods']&.any?
        policy['paymentMethods'].first['paymentMethodType']
      else
        '-'
      end
    end
  end

  def local_policy_for(policy)
    local_policies.find_by(ebay_policy_id: policy[policy_id_key])
  end

  def show_path(local_policy)
    if policy_type == 'fulfillment'
      account_external_account_fulfillment_policy_path(current_account, external_account, local_policy)
    else
      account_external_account_payment_policy_path(current_account, external_account, local_policy)
    end
  end


  def create_button_text
    "Create #{policy_type.humanize} Policy"
  end

  def create_button_path
    if policy_type == 'fulfillment'
      new_account_external_account_fulfillment_policy_path(current_account, external_account)
    else
      new_account_external_account_payment_policy_path(current_account, external_account)
    end
  end

  def no_policies_message
    "No #{policy_type} policies created yet."
  end
end