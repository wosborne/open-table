class InventoryUnit < ApplicationRecord
  belongs_to :variant
  validates :serial_number, presence: true, uniqueness: true
  enum :status, %w[in_stock sold reserved]
end
