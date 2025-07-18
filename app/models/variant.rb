class Variant < ApplicationRecord
  has_paper_trail only: [:sku, :price]

  belongs_to :product
  has_many :variant_option_values, dependent: :destroy
  has_many :product_options, through: :variant_option_values
  has_many :product_option_values, through: :variant_option_values
  has_many :inventory_units, dependent: :destroy

  validates :sku, presence: true, uniqueness: { scope: :product_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  before_update :prevent_sku_change

  accepts_nested_attributes_for :variant_option_values, allow_destroy: true, reject_if: :all_blank

  def suggested_sku
    parts = [ product.name ]
    product.product_options.each do |opt|
      vov = variant_option_values.find { |v| v.product_option_id == opt.id }
      parts << vov&.product_option_value&.value.to_s
    end
    parts.join("").delete(" ").upcase
  end

  def external_id_for(external_account_product_id)
    external_ids && external_ids[external_account_product_id.to_s]
  end

  def set_external_id_for(external_account_product_id, value)
    self.external_ids ||= {}
    self.external_ids[external_account_product_id.to_s] = value
    save!
  end

  def inventory_count
    inventory_units.in_stock.count
  end

  def title
    sku
  end

  def regenerate_sku!
    @allow_sku_change = true
    update!(sku: suggested_sku)
    @allow_sku_change = false
  end

  def sku_version_number
    versions.count + 1
  end

  def sku_history
    versions.reorder(:created_at).map do |version|
      {
        version: version.reify&.sku || sku,
        changed_at: version.created_at,
        version_number: version.index + 1
      }
    end
  end

  def previous_sku
    # Get the most recent version that represents the state before the last change
    last_version = versions.order(:created_at).last
    last_version&.reify&.sku
  end

  private

  def prevent_sku_change
    if sku_changed? && persisted? && !@allow_sku_change
      errors.add(:sku, "cannot be changed after save")
      throw :abort
    end
  end
end
