class OrderLineItem < ApplicationRecord
  belongs_to :order
  belongs_to :variant, optional: true
  belongs_to :inventory_unit, optional: true

  TABLE_COLUMNS = attribute_names - [ "external_line_item_id" ]

  validates :external_line_item_id, :quantity, :price, presence: true
  validates :external_line_item_id, uniqueness: { scope: :order_id }
end
