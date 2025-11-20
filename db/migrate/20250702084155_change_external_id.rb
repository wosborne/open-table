class ChangeExternalId < ActiveRecord::Migration[8.0]
  def change
    change_column :external_account_products, :external_id, :string, null: true, default: nil
  end
end
