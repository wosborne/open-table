class AddEbayCategoryToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :ebay_category_id, :string
    add_column :products, :ebay_category_name, :string
  end
end
