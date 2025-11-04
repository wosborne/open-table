class ExternalServiceFactory
  def self.for(external_account)
    case external_account.service_name
    when 'shopify'
      ShopifyService.new(external_account: external_account)
    else
      raise ArgumentError, "Unknown service: #{external_account.service_name}"
    end
  end
end