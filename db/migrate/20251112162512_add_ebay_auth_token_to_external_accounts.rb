class AddEbayAuthTokenToExternalAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :external_accounts, :ebay_auth_token, :text
  end
end
