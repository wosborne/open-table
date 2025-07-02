class AddDomainToExternalAccount < ActiveRecord::Migration[8.0]
  def change
    add_column :external_accounts, :domain, :string, null: true, default: nil
  end
end
