class BaseExternalService
  def initialize(external_account:)
    @external_account = external_account
    @domain = external_account.domain
    @access_token = external_account.api_token
  end

  def publish_product(product_params)
    raise NotImplementedError, "Subclasses must implement #publish_product"
  end

  def remove_product(product_id)
    raise NotImplementedError, "Subclasses must implement #remove_product"
  end

  def get_products
    raise NotImplementedError, "Subclasses must implement #get_products"
  end

  protected

  attr_reader :external_account, :domain, :access_token

  def with_token_refresh(&block)
    begin
      block.call
    rescue => e
      if token_expired?(e) && refresh_access_token
        block.call
      else
        raise e
      end
    end
  end

  def token_expired?(error)
    raise NotImplementedError, "Subclasses must implement #token_expired?"
  end

  def refresh_access_token
    raise NotImplementedError, "Subclasses must implement #refresh_access_token"
  end
end
