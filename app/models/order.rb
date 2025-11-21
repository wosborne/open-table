class Order < ApplicationRecord
  belongs_to :external_account
  has_many :order_line_items, dependent: :destroy

  TABLE_COLUMNS = attribute_names - [ "external_id" ]
  SEARCHABLE_ATTRIBUTES = [ "id", "name", "currency", "total_price", "financial_status", "fulfillment_status", "payment_status" ]

  validates :external_account, :external_id, :currency, :total_price, :external_created_at, presence: true
  validates :external_id, uniqueness: { scope: :external_account_id }

  after_create :notify_order_created

  private

  def notify_order_created
    SaleNotificationNotifier.with(order: self).deliver_later
  end
end
