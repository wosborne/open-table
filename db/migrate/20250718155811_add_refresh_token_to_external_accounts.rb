class AddRefreshTokenToExternalAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :external_accounts, :refresh_token, :string
  end
end
