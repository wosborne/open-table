class RemoveEbayFieldsFromInventoryUnits < ActiveRecord::Migration[8.0]
  def change
    remove_column :inventory_units, :ebay_listing_status, :string
    remove_column :inventory_units, :ebay_listing_id, :string
    remove_column :inventory_units, :ebay_price, :decimal
    remove_column :inventory_units, :ebay_listed_at, :datetime
    remove_column :inventory_units, :ebay_url, :string
  end
end
