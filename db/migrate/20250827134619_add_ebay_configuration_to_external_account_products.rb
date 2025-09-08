class AddEbayConfigurationToExternalAccountProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :external_account_products, :ebay_category_id, :string
    add_column :external_account_products, :ebay_category_name, :string
    add_column :external_account_products, :ebay_field_mappings, :json
  end
end
