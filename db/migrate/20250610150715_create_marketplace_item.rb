class CreateMarketplaceItem < ActiveRecord::Migration[8.0]
  def change
    create_table :marketplace_items do |t|
      t.references :item

      t.timestamps
    end
  end
end
