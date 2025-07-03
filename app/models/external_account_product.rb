class ExternalAccountProduct < ApplicationRecord
  belongs_to :external_account
  belongs_to :product

  enum :status, [ :active, :draft ]

  after_create :add_to_external_account

  def update_on_external_account
    shopify = Shopify.new(
      shop_domain: external_account.domain,
      access_token: external_account.api_token
    )

    options = product.product_options.map do |option|
      {
        id: option.external_id_for(self.id),
        name: option.name,
        values: option.product_option_values.map(&:value)
      }
    end

    variants = product.variants.map do |variant|
      option_values = product.product_options.map do |option|
        vov = variant.variant_option_values.find { |v| v.product_option_id == option.id }
        vov&.product_option_value&.value
      end
      variant_hash = {
        id: variant.external_id_for(self.id),
        sku: variant.sku,
        price: variant.price
      }
      option_values.each_with_index do |val, idx|
        variant_hash["option#{idx+1}"] = val
      end
      variant_hash
    end

    shopify_product = shopify.publish_product({
      id: self.external_id, # Only present if already synced
      title: product.name,
      variants: variants,
      options: options
    })
    # Save the Shopify product ID if not already set (shouldn't happen here, but for safety)
    if self.external_id.blank? && shopify_product && shopify_product["id"]
      self.update_column(:external_id, shopify_product["id"])
    end
    sync_shopify_ids(shopify_product)
  end

  private

  def add_to_external_account
    shopify = Shopify.new(
      shop_domain: external_account.domain,
      access_token: external_account.api_token
    )

    options = product.product_options.map do |option|
      {
        id: option.external_id_for(self.id),
        name: option.name,
        values: option.product_option_values.map(&:value)
      }
    end

    variants = product.variants.map do |variant|
      option_values = product.product_options.map do |option|
        vov = variant.variant_option_values.find { |v| v.product_option_id == option.id }
        vov&.product_option_value&.value
      end
      variant_hash = {
        id: variant.external_id_for(self.id),
        sku: variant.sku,
        price: variant.price
      }
      option_values.each_with_index do |val, idx|
        variant_hash["option#{idx+1}"] = val
      end
      variant_hash
    end

    shopify_product = shopify.publish_product({
      title: product.name,
      variants: variants,
      options: options
    })
    # Save the Shopify product ID if not already set
    if self.external_id.blank? && shopify_product && shopify_product["id"]
      self.update_column(:external_id, shopify_product["id"])
    end
    sync_shopify_ids(shopify_product)
  end

  def sync_shopify_ids(shopify_product)
    # Sync options
    if shopify_product["options"]
      shopify_product["options"].each do |shopify_option|
        local_option = product.product_options.find_by(name: shopify_option["name"])
        local_option&.set_external_id_for(self.id, shopify_option["id"])
      end
    end
    # Sync variants
    if shopify_product["variants"]
      shopify_product["variants"].each do |shopify_variant|
        local_variant = product.variants.find_by(sku: shopify_variant["sku"])
        local_variant&.set_external_id_for(self.id, shopify_variant["id"])
      end
    end
  end
end
