class AddEbaySessionIdToExternalAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :external_accounts, :ebay_session_id, :string
  end
end
