class AddEbayUserInfoToExternalAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :external_accounts, :ebay_user_id, :string
    add_column :external_accounts, :ebay_username, :string
    add_column :external_accounts, :ebay_display_name, :string
    add_column :external_accounts, :ebay_email, :string
  end
end
