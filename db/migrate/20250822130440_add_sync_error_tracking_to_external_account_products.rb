class AddSyncErrorTrackingToExternalAccountProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :external_account_products, :last_sync_error, :text
    add_column :external_account_products, :last_sync_attempted_at, :datetime
  end
end
