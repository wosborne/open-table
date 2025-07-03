class ExternalAccountProduct < ApplicationRecord
  belongs_to :external_account
  belongs_to :product

  enum :status, [ :active, :draft ]

  after_create :add_to_external_account

  private

  def add_to_external_account
    shopify = Shopify.new(
      shop_domain: external_account.domain,
      access_token: external_account.api_token
    )

    # Build Shopify options array
    options = product.product_options.map do |option|
      {
        name: option.name,
        values: option.product_option_values.pluck(:value)
      }
    end

    # Build Shopify variants array
    variants = product.variants.map do |variant|
      option_values = product.product_options.map do |option|
        vov = variant.variant_option_values.find { |v| v.product_option_id == option.id }
        vov&.product_option_value&.value
      end
      variant_hash = {
        sku: variant.sku,
        price: variant.price
      }
      # Shopify expects option1, option2, ...
      option_values.each_with_index do |val, idx|
        variant_hash["option#{idx+1}"] = val
      end
      variant_hash
    end

    shopify.publish_product({
      title: product.name,
      variants: variants,
      options: options
    })
  end
end
