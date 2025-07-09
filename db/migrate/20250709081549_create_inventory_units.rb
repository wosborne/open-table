class CreateInventoryUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :inventory_units do |t|
      t.references :variant, null: false, foreign_key: true
      t.string :serial_number
      t.integer :status, null: false, default: 0

      t.timestamps
    end
    add_index :inventory_units, :serial_number, unique: true
  end
end
