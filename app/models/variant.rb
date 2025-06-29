class Variant < ApplicationRecord
  belongs_to :product

  validates :sku, presence: true, uniqueness: { scope: :product_id }
  validates :name, presence: true, uniqueness: { scope: :product_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_sku, on: :create

  private

  def set_sku
    self.sku = "#{product.name}#{name}".gsub(/\s+/, "").upcase
  end
end
