class EbayFulfillmentPolicy < EbayBusinessPolicy
  POLICY_TYPE = 'fulfillment'
  
  def handling_time
    ebay_attributes.dig("handlingTime", "value")
  end

  def service_code
    first_shipping_service&.dig("shippingServiceCode")
  end

  def free_shipping?
    first_shipping_service&.dig("freeShipping") || false
  end

  def cost
    first_shipping_service&.dig("shippingCost", "value")&.to_f
  end

  def currency
    first_shipping_service&.dig("shippingCost", "currency") || "GBP"
  end

  def category_default?
    ebay_attributes.dig("categoryTypes")&.any? { |ct| ct["default"] } || false
  end

  private

  def first_shipping_service
    @first_shipping_service ||= ebay_attributes
      .dig("shippingOptions")
      &.first
      &.dig("shippingServices")
      &.first
  end
end