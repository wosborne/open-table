class CreateShopifyOrderJob < ApplicationJob
  queue_as :default

  def perform(shop_domain:, webhook:)
    # Find the external account for this shop
    external_account = ExternalAccount.find_by(service_name: "shopify", domain: shop_domain)
    return unless external_account

    order_data = webhook.with_indifferent_access

    # Create or update the order
    order = Order.find_or_initialize_by(
      external_account: external_account,
      external_id: order_data[:id].to_s
    )
    order.name = order_data[:name]
    order.currency = order_data[:currency]
    order.total_price = order_data[:total_price]
    order.external_created_at = order_data[:created_at]
    order.financial_status = order_data[:financial_status]
    order.fulfillment_status = order_data[:fulfillment_status]
    order.save!

    # Remove existing line items to avoid duplicates
    order.order_line_items.destroy_all

    # Create line items
    Array(order_data[:line_items]).each do |item|
      # Find the matching variant by SKU
      variant = Variant.where(sku: item[:sku]).order(:created_at).first
      # Find the oldest available inventory unit for this variant
      inventory_unit = variant&.inventory_units&.in_stock&.order(:created_at)&.first
      # Reserve the inventory unit if found
      if inventory_unit
        inventory_unit.update!(status: :reserved)
      end
      order.order_line_items.create!(
        external_line_item_id: item[:id].to_s,
        sku: item[:sku],
        title: item[:title],
        quantity: item[:quantity],
        price: item[:price],
        inventory_unit: inventory_unit
      )
    end
  end
end
