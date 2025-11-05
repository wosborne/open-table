class CreateEbayBusinessPolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :ebay_business_policies do |t|
      t.references :external_account, null: false, foreign_key: true
      t.string :policy_type, null: false
      t.string :ebay_policy_id
      t.string :name
      t.string :marketplace_id

      t.timestamps
    end
    
    add_index :ebay_business_policies, [:external_account_id, :policy_type]
    add_index :ebay_business_policies, :ebay_policy_id, unique: true
  end
end
