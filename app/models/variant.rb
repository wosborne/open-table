class Variant < ApplicationRecord
  has_paper_trail only: [ :sku, :price ]

  TABLE_COLUMNS = attribute_names - [ "id", "external_ids", "product_id" ] + [ "product_name", "inventory_count" ]

  belongs_to :product
  has_many :variant_option_values, dependent: :destroy
  has_many :product_options, through: :variant_option_values
  has_many :product_option_values, through: :variant_option_values
  has_many :inventory_units, dependent: :destroy

  validates :sku, presence: true, uniqueness: { scope: :product_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :create_variant_option_values, :set_sku_if_blank
  before_update :prevent_sku_change

  attr_accessor :product_option_values_attributes
  
  def product_option_values_attributes=(attributes)
    @product_option_values_params = attributes.values if attributes.is_a?(Hash)
  end

  def suggested_sku
    parts = []

    # Get model first (if exists)
    model_option = product.product_options.find { |opt| opt.name.downcase == "model" }
    if model_option
      model_vov = variant_option_values.find { |v| v.product_option_id == model_option.id }
      parts << model_vov&.product_option_value&.value.to_s if model_vov
    elsif product.ebay_aspects&.dig("Model").present?
      # Use eBay aspects Model if no model product option exists
      parts << product.ebay_aspects["Model"]
    end

    # Add all other options (excluding model)
    product.product_options.each do |opt|
      next if opt.name.downcase == "model"
      vov = variant_option_values.find { |v| v.product_option_id == opt.id }
      parts << vov&.product_option_value&.value.to_s if vov
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

  def product_name
    product&.name
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


  def create_variant_option_values
    return unless new_record?
    
    # Process the nested product_option_values_attributes manually
    if @product_option_values_params
      @product_option_values_params.each do |attrs|
        next if attrs[:value].blank? || attrs[:product_option_id].blank?
        
        product_option = product.product_options.find(attrs[:product_option_id])
        
        # Find or create the ProductOptionValue
        product_option_value = product_option.product_option_values.find_or_create_by!(
          value: attrs[:value]
        )
        
        # Create the linking VariantOptionValue
        variant_option_values.build(
          product_option: product_option,
          product_option_value: product_option_value
        )
      end
    end
  end

  def set_sku_if_blank
    self.sku = suggested_sku if sku.blank?
  end

  def prevent_sku_change
    if sku_changed? && persisted? && !@allow_sku_change
      errors.add(:sku, "cannot be changed after save")
      throw :abort
    end
  end
end
