class ShopifyWebhookHandler
  extend ShopifyAPI::Webhooks::WebhookHandler

  def self.handle(data:)
    ShopifyWebhookJob.perform_later(
      topic: data.topic,
      shop_domain: data.shop,
      webhook: data.body
    )
  end
end
