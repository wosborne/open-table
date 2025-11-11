class AddTypeToEbayBusinessPolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :ebay_business_policies, :type, :string
    add_index :ebay_business_policies, :type
    
    # Populate existing records with correct type
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE ebay_business_policies 
          SET type = CASE 
            WHEN policy_type = 'fulfillment' THEN 'EbayFulfillmentPolicy'
            WHEN policy_type = 'payment' THEN 'EbayPaymentPolicy'
            WHEN policy_type = 'return' THEN 'EbayReturnPolicy'
            ELSE 'EbayBusinessPolicy'
          END
        SQL
      end
    end
  end
end
