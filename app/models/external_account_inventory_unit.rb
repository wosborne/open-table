class ExternalAccountInventoryUnit < ApplicationRecord
  belongs_to :external_account
  belongs_to :inventory_unit

  validates :external_account_id, uniqueness: { scope: :inventory_unit_id }

  def status
    marketplace_data&.dig('status') || 'not_listed'
  end

  def listing_id
    marketplace_data&.dig('listing_id')
  end

  def price
    marketplace_data&.dig('price')&.to_f
  end

  def listed_at
    timestamp = marketplace_data&.dig('listed_at')
    timestamp ? Time.parse(timestamp) : nil
  rescue ArgumentError
    nil
  end

  def url
    marketplace_data&.dig('url')
  end

  def status_label
    case status
    when 'not_listed', nil then 'Not Listed'
    when 'draft' then 'Draft'
    when 'active' then 'Listed'
    when 'sold' then 'Sold'
    when 'ended' then 'Ended'
    end
  end

  def perform_action(action)
    case action
    when 'publish'
      publish_listing
    when 'end'
      end_listing
    when 'relist'
      relist_listing
    when 'archive'
      archive_listing
    else
      { success: false, message: "Unknown action: #{action}" }
    end
  end

  private

  def publish_listing
    update_marketplace_data(
      status: 'active',
      listed_at: Time.current.iso8601,
      price: inventory_unit.variant&.price
    )
    { success: true, message: "Listed on #{external_account.service_name.humanize} successfully!" }
  end

  def end_listing
    update_marketplace_data(status: 'ended')
    { success: true, message: "#{external_account.service_name.humanize} listing ended." }
  end

  def relist_listing
    update_marketplace_data(
      status: 'active',
      listed_at: Time.current.iso8601
    )
    { success: true, message: "Relisted on #{external_account.service_name.humanize}!" }
  end

  def archive_listing
    destroy
    { success: true, message: "#{external_account.service_name.humanize} listing archived." }
  end

  def update_marketplace_data(updates)
    self.marketplace_data = (marketplace_data || {}).merge(updates.stringify_keys)
    save
  end
end