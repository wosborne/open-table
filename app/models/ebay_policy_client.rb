class EbayPolicyClient
  attr_reader :external_account, :api_client

  def initialize(external_account)
    @external_account = external_account
    @api_client = EbayApiClient.new(external_account)
  end

  def get_fulfillment_policies
    get_policies("fulfillment", "fulfillmentPolicies")
  end

  def get_payment_policies
    get_policies("payment", "paymentPolicies")
  end

  def get_return_policies
    get_policies("return", "returnPolicies")
  end


  def get_default_fulfillment_policy_id
    fulfillment_policies = get_fulfillment_policies
    
    # Look for "Collection" policy first
    collection_policy = fulfillment_policies.find { |policy| policy['name'] == 'Collection' }
    return collection_policy['fulfillmentPolicyId'] if collection_policy
    
    # Fallback to first policy if "Collection" not found
    fulfillment_policies.first&.dig('fulfillmentPolicyId')
  end

  def get_default_payment_policy_id
    payment_policies = get_payment_policies
    
    # Look for "Cash" policy first
    cash_policy = payment_policies.find { |policy| policy['name'] == 'Cash' }
    return cash_policy['paymentPolicyId'] if cash_policy
    
    # Fallback to first policy if "Cash" not found
    payment_policies.first&.dig('paymentPolicyId')
  end

  def get_default_return_policy_id
    return_policies = get_return_policies
    return_policies.first&.dig('returnPolicyId')
  end

  def get_all_default_policy_ids
    {
      fulfillment_policy_id: get_default_fulfillment_policy_id,
      payment_policy_id: get_default_payment_policy_id,
      return_policy_id: get_default_return_policy_id
    }
  end

  def get_all_fulfillment_policies
    result = @api_client.get("/sell/account/v1/fulfillment_policy", { marketplace_id: "EBAY_GB" })
    
    if result[:success]
      Rails.logger.info "Fetched fulfillment policies: #{result[:data].inspect}"
      result[:data]['fulfillmentPolicies'] || []
    else
      Rails.logger.error "Failed to fetch fulfillment policies: #{result[:error]}"
      []
    end
  end

  def has_required_policies?
    policy_ids = get_all_default_policy_ids
    policy_ids.values.all?(&:present?)
  end

  def missing_policies
    policy_ids = get_all_default_policy_ids
    missing = []
    
    missing << "fulfillment" if policy_ids[:fulfillment_policy_id].nil?
    missing << "payment" if policy_ids[:payment_policy_id].nil?
    missing << "return" if policy_ids[:return_policy_id].nil?
    
    missing
  end


  def is_opted_into_business_policies?
    result = @api_client.get("/sell/account/v1/program/get_opted_in_programs")
    
    if result[:success]
      opted_in_programs = result[:data]['programs'] || []
      
      business_policy_program = opted_in_programs.find do |program|
        program['programType'] == 'SELLING_POLICY_MANAGEMENT'
      end
      
      business_policy_program.present?
    else
      false
    end
  end

  def opt_into_business_policies
    payload = {
      programType: "SELLING_POLICY_MANAGEMENT"
    }
    
    result = @api_client.post("/sell/account/v1/program/opt_in", payload)
    
    if result[:success]
      { success: true, message: "Successfully opted into Business Policies Management. This can take up to 24 hours to process." }
    else
      { success: false, message: "Failed to opt into Business Policies: #{result[:error]}" }
    end
  end

  private

  def get_policies(policy_type, response_key)
    result = @api_client.get("/sell/account/v1/#{policy_type}_policy", { marketplace_id: "EBAY_GB" })
    
    if result[:success]
      result[:data][response_key] || []
    else
      []
    end
  end
end