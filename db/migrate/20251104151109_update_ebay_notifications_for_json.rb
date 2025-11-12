class UpdateEbayNotificationsForJson < ActiveRecord::Migration[8.0]
  def change
    # Add new JSON fields
    add_column :ebay_notifications, :raw_json, :text
    add_column :ebay_notifications, :topic_id, :string
    add_column :ebay_notifications, :schema_version, :string
    add_column :ebay_notifications, :event_id, :string
    add_column :ebay_notifications, :signature_verified, :boolean, default: false
    
    # Make raw_xml nullable since we'll support both formats during transition
    change_column_null :ebay_notifications, :raw_xml, true
    
    # Add indexes for new fields
    add_index :ebay_notifications, :topic_id
    add_index :ebay_notifications, :event_id
    add_index :ebay_notifications, :signature_verified
  end
end
