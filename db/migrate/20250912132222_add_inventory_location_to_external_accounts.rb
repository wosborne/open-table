class AddInventoryLocationToExternalAccounts < ActiveRecord::Migration[8.0]
  def change
    add_reference :external_accounts, :inventory_location, null: true, foreign_key: { to_table: :locations }
  end
end
