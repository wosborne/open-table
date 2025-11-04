class CreateEbayNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :ebay_notifications do |t|
      t.string :notification_type, null: false
      t.text :raw_xml, null: false
      t.jsonb :parsed_data
      t.string :ebay_item_id
      t.string :ebay_transaction_id
      t.string :status, default: 'received'
      t.text :error_message
      t.string :request_method
      t.string :content_type
      t.jsonb :headers
      t.references :external_account, null: false, foreign_key: true
      t.references :inventory_unit, null: true, foreign_key: true
      t.references :order, null: true, foreign_key: true

      t.timestamps
    end

    add_index :ebay_notifications, :notification_type
    add_index :ebay_notifications, :ebay_item_id
    add_index :ebay_notifications, :status
    add_index :ebay_notifications, :created_at
  end
end
