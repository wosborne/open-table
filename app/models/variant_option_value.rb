class VariantOptionValue < ApplicationRecord
  belongs_to :variant
  belongs_to :product_option
  belongs_to :product_option_value

  validates :product_option_id, uniqueness: { scope: [ :variant_id, :product_option_value_id ] }
end
