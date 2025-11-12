class AddNotificationFieldsToExternalAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :external_accounts, :webhook_verification_token, :string
    add_column :external_accounts, :notification_destination_id, :string
    add_column :external_accounts, :notification_config_id, :string
  end
end
