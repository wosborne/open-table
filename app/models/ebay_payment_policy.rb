class EbayPaymentPolicy < EbayBusinessPolicy
  POLICY_TYPE = 'payment'
  
  def immediate_pay?
    ebay_attributes.dig("immediatePay") || false
  end

  def payment_methods
    ebay_attributes.dig("paymentMethods") || []
  end

  def payment_instructions
    ebay_attributes.dig("paymentInstructions")
  end

  def category_default?
    ebay_attributes.dig("categoryTypes")&.any? { |ct| ct["default"] } || false
  end

  def deposit_details
    ebay_attributes.dig("depositDetails")
  end

  def full_payment_due_in
    deposit_details&.dig("dueIn", "value")
  end

  def deposit_amount
    deposit_details&.dig("depositAmount", "value")&.to_f
  end

  def deposit_currency
    deposit_details&.dig("depositAmount", "currency") || "GBP"
  end
end