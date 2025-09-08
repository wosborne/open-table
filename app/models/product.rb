class Product < ApplicationRecord
  belongs_to :account
  TABLE_COLUMNS = attribute_names - [ "account_id" ] + [ "in_stock" ]
  has_many :product_options, dependent: :destroy
  has_many :product_option_values, through: :product_options
  has_many :variants, dependent: :destroy
  has_many :external_account_products, dependent: :destroy
  has_many :inventory_units, through: :variants

  validates :name, presence: true, uniqueness: { scope: :account_id }

  accepts_nested_attributes_for :variants, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :product_options, allow_destroy: true, reject_if: :all_blank

  # Limit to 3 options
  validate :options_limit

  # after_save :update_external_accounts

  def options_limit
    errors.add(:product_options, "can't have more than 3 options") if product_options.size > 3
  end

  # Generate all possible variant combinations from option values
  def all_variant_combinations
    return [] if product_options.empty?
    value_lists = product_options.map { |opt| opt.product_option_values.to_a }
    return [] if value_lists.any?(&:empty?)
    
    # Handle single option case
    if value_lists.length == 1
      return value_lists.first.map { |val| [val] }
    end
    
    # Handle multiple options
    value_lists.first.product(*value_lists[1..])
  end

  # Generate variants for all combinations of option values (in memory only, do not persist)
  def generate_variants_from_options
    combos = all_variant_combinations
    return if combos.empty?
    
    combos.each do |combination|
      # Ensure combination is an array
      combination = [combination] unless combination.is_a?(Array)
      
      # Check if a variant with this exact set of option values exists
      next if variants.any? do |variant|
        existing_vals = variant.variant_option_values.map(&:product_option_value_id).sort
        combo_vals = combination.map(&:id).sort
        existing_vals == combo_vals
      end
      
      variant = variants.build
      combination.each do |value|
        variant.variant_option_values.build(
          product_option: value.product_option,
          product_option_value: value
        )
      end
    end
  end

  def in_stock
    variants.sum(&:inventory_count)
  end

  # Check which variants would be affected by option value changes
  def variants_affected_by_option_changes
    affected_variants = []
    variants.includes(variant_option_values: :product_option_value).each do |variant|
      next unless variant.persisted? && variant.sku.present?
      
      new_suggested_sku = variant.suggested_sku
      if variant.sku != new_suggested_sku
        affected_variants << {
          variant: variant,
          current_sku: variant.sku,
          suggested_sku: new_suggested_sku
        }
      end
    end
    affected_variants
  end

  private

  def update_external_accounts
    external_account_products.find_each(&:sync_to_external_account)
  end
end
