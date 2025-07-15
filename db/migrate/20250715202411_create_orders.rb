class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :external_account, null: false, foreign_key: true
      t.string   :external_id, null: false
      t.string   :name
      t.string   :currency, null: false
      t.decimal  :total_price, precision: 12, scale: 2, null: false
      t.datetime :external_created_at, null: false
      t.string   :financial_status
      t.string   :fulfillment_status

      t.timestamps
    end

    create_table :order_line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.string     :external_line_item_id, null: false, index: true
      t.string     :sku
      t.string     :title
      t.integer    :quantity, null: false
      t.decimal    :price, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
