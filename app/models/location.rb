class Location < ApplicationRecord
  TABLE_COLUMNS = attribute_names - [ "account_id" ]

  belongs_to :account
  has_many :inventory_units, dependent: :nullify

  validates :name, presence: true
  validates :address_line_1, presence: true
  validates :city, presence: true
  validates :postcode, presence: true
  validates :country, presence: true

  def full_address
    lines = [address_line_1, address_line_2, city, state, postcode, country].compact
    lines.join(', ')
  end
end
