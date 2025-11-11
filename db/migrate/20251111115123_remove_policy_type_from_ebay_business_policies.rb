class RemovePolicyTypeFromEbayBusinessPolicies < ActiveRecord::Migration[8.0]
  def change
    remove_index :ebay_business_policies, column: [:external_account_id, :policy_type], name: "idx_on_external_account_id_policy_type_4eaa9fd4b2"
    remove_column :ebay_business_policies, :policy_type, :string
  end
end
