class OrderLineItem < ApplicationRecord
  belongs_to :order

  validates :external_line_item_id, :quantity, :price, presence: true
  validates :external_line_item_id, uniqueness: { scope: :order_id }
end
