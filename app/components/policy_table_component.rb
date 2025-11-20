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
    case policy_type
    when "fulfillment"
      "Shipping Service"
    when "payment"
      "Payment Method"
    when "return"
      "Return Period"
    end
  end

  def policy_id_key
    case policy_type
    when "fulfillment"
      "fulfillmentPolicyId"
    when "payment"
      "paymentPolicyId"
    when "return"
      "returnPolicyId"
    end
  end

  def detail_value(policy)
    case policy_type
    when "fulfillment"
      if policy["shippingOptions"]&.any? && policy["shippingOptions"].first["shippingServices"]&.any?
        policy["shippingOptions"].first["shippingServices"].first["shippingServiceCode"]
      else
        "-"
      end
    when "payment"
      if policy["paymentMethods"]&.any?
        policy["paymentMethods"].first["paymentMethodType"]
      else
        "-"
      end
    when "return"
      if policy["returnPeriod"]
        "#{policy['returnPeriod']['value']} #{policy['returnPeriod']['unit']&.downcase}"
      else
        "-"
      end
    end
  end

  def local_policy_for(policy)
    local_policies.find_by(ebay_policy_id: policy[policy_id_key])
  end

  def show_path(local_policy)
    case policy_type
    when "fulfillment"
      account_external_account_fulfillment_policy_path(current_account, external_account, local_policy)
    when "payment"
      account_external_account_payment_policy_path(current_account, external_account, local_policy)
    when "return"
      account_external_account_return_policy_path(current_account, external_account, local_policy)
    end
  end

  def create_button_text
    "Create #{policy_type.humanize} Policy"
  end

  def create_button_path
    case policy_type
    when "fulfillment"
      new_account_external_account_fulfillment_policy_path(current_account, external_account)
    when "payment"
      new_account_external_account_payment_policy_path(current_account, external_account)
    when "return"
      new_account_external_account_return_policy_path(current_account, external_account)
    end
  end

  def no_policies_message
    "No #{policy_type} policies created yet."
  end
end
