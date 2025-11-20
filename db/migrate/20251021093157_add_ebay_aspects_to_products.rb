class AddEbayAspectsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :ebay_aspects, :jsonb
  end
end
