class Item < ApplicationRecord
  belongs_to :table

  has_many :outgoing_links, class_name: "Link", foreign_key: :from_item_id, dependent: :destroy
  has_many :incoming_links, class_name: "Link", foreign_key: :to_item_id, dependent: :destroy

  has_many :linked_items, through: :outgoing_links, source: :to_item
  has_many :linked_from_items, through: :incoming_links, source: :from_item

  def set_property(params)
    properties[params[:property_id]] = params[:value]
    save
  end
end
