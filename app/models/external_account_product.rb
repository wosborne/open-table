class ExternalAccountProduct < ApplicationRecord
  belongs_to :external_account
  belongs_to :product

  enum :status, [ :active, :draft ]

  after_create :add_to_external_account

  private

  def add_to_external_account
    binding.pry
    shopify = Shopify.new(
      shop_domain: external_account.domain,
      access_token: external_account.api_token
    )

    variants = product.variants.map do |variant|
      {
        option1: variant.name,
        sku: variant.sku,
        price: variant.price
      }
    end

    shopify.publish_product({
      title: product.name,
      variants: variants,
      options: { name: "Model" }
    })
  end
end
