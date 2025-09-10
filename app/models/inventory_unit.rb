class InventoryUnit < ApplicationRecord
  include Ebayable
  
  TABLE_COLUMNS = attribute_names - [ "account_id" ]

  belongs_to :account
  belongs_to :variant
  has_many_attached :images
  has_many :external_account_inventory_units, dependent: :destroy
  validates :serial_number, presence: true, uniqueness: true
  enum :status, %w[in_stock sold reserved]

  scope :in_stock, -> { where(status: :in_stock) }

  def ebay_listing(external_account)
    external_account_inventory_units.find_by(external_account: external_account)
  end

  def ebay_listing_for_account(account)
    ebay_account = account.external_accounts.find_by(service_name: 'ebay')
    return nil unless ebay_account
    ebay_listing(ebay_account)
  end

end
