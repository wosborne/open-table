class ProductOption < ApplicationRecord
  belongs_to :product
  has_many :product_option_values, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :product_id }

  accepts_nested_attributes_for :product_option_values, allow_destroy: true, reject_if: :all_blank
end
