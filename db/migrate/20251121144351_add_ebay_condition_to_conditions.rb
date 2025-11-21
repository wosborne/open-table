class AddEbayConditionToConditions < ActiveRecord::Migration[8.0]
  def change
    add_column :conditions, :ebay_condition, :string
  end
end
