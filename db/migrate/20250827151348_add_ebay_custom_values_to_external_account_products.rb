class AddEbayCustomValuesToExternalAccountProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :external_account_products, :ebay_custom_values, :json
  end
end
