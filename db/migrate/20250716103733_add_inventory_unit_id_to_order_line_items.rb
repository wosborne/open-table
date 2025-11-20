class AddInventoryUnitIdToOrderLineItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :order_line_items, :inventory_unit, null: true, foreign_key: true
  end
end
