class ProductOptionValue < ApplicationRecord
  belongs_to :product_option

  validates :value, presence: true
  validates :value, uniqueness: { scope: :product_option_id }
end
