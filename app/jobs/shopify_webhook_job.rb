class ShopifyWebhookJob < ApplicationJob
  queue_as :default

  def perform(topic:, shop_domain:, webhook:)
    case topic
    when "orders/create"
      CreateShopifyOrderJob.perform_later(shop_domain: shop_domain, webhook: webhook)
    when "inventory_items/update"
      # Update inventory logic
    end
  end
end
