class AddLocationToInventoryUnits < ActiveRecord::Migration[8.0]
  def change
    add_reference :inventory_units, :location, null: true, foreign_key: true
  end
end
