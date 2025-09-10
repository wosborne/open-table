class CreateExternalAccountInventoryUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :external_account_inventory_units do |t|
      t.references :external_account, null: false, foreign_key: true
      t.references :inventory_unit, null: false, foreign_key: true
      t.json :marketplace_data

      t.timestamps
    end
    
    add_index :external_account_inventory_units, [:external_account_id, :inventory_unit_id], 
              unique: true, name: 'index_eaiu_on_external_account_and_inventory_unit'
  end
end
