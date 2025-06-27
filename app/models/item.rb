class Item < ApplicationRecord
  belongs_to :table

  has_many :outgoing_links, class_name: "Link", foreign_key: :from_item_id, dependent: :destroy
  has_many :incoming_links, class_name: "Link", foreign_key: :to_item_id, dependent: :destroy

  has_many :linked_items, through: :outgoing_links, source: :to_item
  has_many :linked_from_items, through: :incoming_links, source: :from_item

  before_create :set_created_at_property
  before_create :set_id_property

  before_save :set_updated_at_property

  # after_save :update_shopify

  def set_property(params)
    properties[params[:property_id]] = params[:value]
    save
  end

  private

  def set_id_property
    property = table.properties.find_by(type: "Properties::IdProperty")
    if property
      next_id = table.last_item_id + 1
      properties[property.id.to_s] = property.prefix_id(next_id)
      table.update(last_item_id: next_id)
    end
  end

  def set_created_at_property
    created_at_property = table.properties.find_by(name: "Created at")
    updated_at_property = table.properties.find_by(name: "Updated at")
    time = Time.now
    properties[created_at_property.id.to_s] = time
    properties[updated_at_property.id.to_s] = time
  end

  def set_updated_at_property
    property = table.properties.find_by(name: "Updated at")
    properties[property.id.to_s] = Time.zone.now
  end

  def update_shopify
    shopify_property = table.properties.find_by(type: "Properties::ShopifyProperty")
    id_property = table.properties.find_by(type: "Properties::IdProperty")  

    product = Shopify.new(
      shop_domain: "naoaz-test-store.myshopify.com",
      access_token: table.account.external_accounts.find_by(service_name: "shopify")&.api_token
    ).publish_product(
      title: "Test Product",
      sku: properties[id_property.id.to_s]
    )
  end
end
