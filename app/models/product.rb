class Product < ApplicationRecord
  belongs_to :account
  TABLE_COLUMNS = attribute_names - [ "account_id" ] + [ "in_stock" ]
  has_many :product_options, dependent: :destroy
  has_many :product_option_values, through: :product_options
  has_many :variants, dependent: :destroy
  has_many :external_account_products, dependent: :destroy
  has_many :inventory_units, through: :variants

  validates :name, presence: true, uniqueness: { scope: :account_id }
  
  # Allow eBay category assignment
  attr_accessor :ebay_category_data

  # after_save :update_external_accounts

  def in_stock
    inventory_units.in_stock.count
  end

  private

  def update_external_accounts
    external_account_products.find_each(&:sync_to_external_account)
  end
end
