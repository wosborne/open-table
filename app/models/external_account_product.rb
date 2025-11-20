class ExternalAccountProduct < ApplicationRecord
  belongs_to :external_account
  belongs_to :product

  enum :status, [ :active, :draft ]

  after_save :sync_to_external_account
  before_destroy :remove_from_external_account

  def sync_to_external_account
    service = ExternalServiceFactory.for(external_account)

    payload = build_product_payload
    payload[:id] = self.external_id if self.external_id.present?

    external_product = service.publish_product(payload)
    if self.external_id.blank? && external_product && external_product_id(external_product)
      self.update_column(:external_id, external_product_id(external_product))
    end
    sync_external_ids(external_product)
  end

  def remove_from_external_account
    if external_id.present?
      service = ExternalServiceFactory.for(external_account)
      service.remove_product(external_id)
    end
  end

  private

  def build_product_payload
    case external_account.service_name
    when "shopify"
      {
        title: product.name,
        variants: shopify_variants,
        options: shopify_options
      }
    when "ebay"
      {
        title: product.name,
        description: product.description || product.name,
        price: product.variants.first&.price || "0.99",
        sku: product.variants.first&.sku
      }
    else
      raise ArgumentError, "Unknown service: #{external_account.service_name}"
    end
  end

  def external_product_id(external_product)
    case external_account.service_name
    when "shopify"
      external_product["id"]
    when "ebay"
      external_product["ItemID"]
    end
  end

  def sync_external_ids(external_product)
    case external_account.service_name
    when "shopify"
      sync_shopify_ids(external_product)
    when "ebay"
      sync_ebay_ids(external_product)
    end
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

  def sync_ebay_ids(ebay_product)
    # TODO: Implement eBay ID syncing if needed
    # eBay structure is different from Shopify
  end

  def shopify_options
    product.product_options.map do |option|
      {
        id: option.external_id_for(self.id),
        name: option.name,
        values: option.product_option_values.map(&:value)
      }
    end
  end

  def shopify_variants
    product.variants.map do |variant|
      option_values = product.product_options.map do |option|
        vov = variant.variant_option_values.find { |v| v.product_option_id == option.id }
        vov&.product_option_value&.value
      end

      # Skip variants that have any nil option values
      next if option_values.any?(&:nil?)

      variant_hash = {
        id: variant.external_id_for(self.id),
        sku: variant.sku,
        price: variant.price
      }
      option_values.each_with_index do |val, idx|
        variant_hash["option#{idx+1}"] = val
      end
      variant_hash
    end.compact
  end
end
