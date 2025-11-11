class EbayReturnPolicy < EbayBusinessPolicy
  POLICY_TYPE = 'return'
  
  def returns_accepted?
    ebay_attributes.dig("returnsAccepted") || false
  end

  def return_period
    ebay_attributes.dig("returnPeriod", "value")
  end

  def return_period_unit
    ebay_attributes.dig("returnPeriod", "unit")
  end

  def return_method
    ebay_attributes.dig("returnMethod")
  end

  def return_shipping_cost_payer
    ebay_attributes.dig("returnShippingCostPayer")
  end

  def refund_method
    ebay_attributes.dig("refundMethod")
  end

  def restocking_fee_percentage
    ebay_attributes.dig("restockingFeePercentage")&.to_f
  end

  def extended_holiday_returns?
    ebay_attributes.dig("extendedHolidayReturns") || false
  end

  def return_instructions
    ebay_attributes.dig("returnInstructions")
  end

  def category_default?
    ebay_attributes.dig("categoryTypes")&.any? { |ct| ct["default"] } || false
  end
end