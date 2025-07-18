class InventoryUnit < ApplicationRecord
  TABLE_COLUMNS = attribute_names - [ "account_id" ]

  belongs_to :account
  belongs_to :variant
  validates :serial_number, presence: true, uniqueness: true
  enum :status, %w[in_stock sold reserved]

  scope :in_stock, -> { where(status: :in_stock) }
end
