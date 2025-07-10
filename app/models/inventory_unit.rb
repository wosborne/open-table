class InventoryUnit < ApplicationRecord
  TABLE_COLUMNS = attribute_names - [ "account_id" ]

  belongs_to :variant
  validates :serial_number, presence: true, uniqueness: true
  enum :status, %w[in_stock sold reserved]
end
