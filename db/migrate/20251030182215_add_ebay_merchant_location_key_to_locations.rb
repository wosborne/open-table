class AddEbayMerchantLocationKeyToLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :locations, :ebay_merchant_location_key, :string
  end
end
