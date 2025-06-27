class Ebay
  BASE_URL = "https://api.ebay.com/buy/browse/v1".freeze
  AUTH_URL = "https://api.ebay.com/identity/v1/oauth2/token".freeze

  def initialize(access_token = nil)
    @access_token = access_token || fetch_access_token
  end

  def search_items(query, limit = 10)
    response = connection.get("/item_summary/search") do |req|
      req.headers["Authorization"] = "Bearer #{@access_token}"
      req.params["q"] = query
      req.params["limit"] = limit
    end
    JSON.parse(response.body) if response.success?
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end
  end

  def fetch_access_token
    Rails.cache.fetch("ebay_access_token", expires_in: 1.hour) do
      obtain_new_access_token
    end
  end

  def obtain_new_access_token
    response = Faraday.post(AUTH_URL) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.headers["Authorization"] = "Basic #{Base64.strict_encode64("#{app_id}:#{cert_id}")}"
      req.body = "grant_type=client_credentials&scope=https://api.ebay.com/oauth/api_scope"
    end

    JSON.parse(response.body)["access_token"]
  end

  def app_id
    Rails.application.credentials.ebay[:app_id]
  end

  def cert_id
    Rails.application.credentials.ebay[:cert_id]
  end
end
