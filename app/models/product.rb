class Product < ApplicationRecord
  TABLE_COLUMNS = attribute_names - [ "account_id" ]
  has_many :product_options, dependent: :destroy
  has_many :product_option_values, through: :product_options
  has_many :variants, dependent: :destroy
  has_many :external_account_products, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }

  accepts_nested_attributes_for :variants, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :product_options, allow_destroy: true, reject_if: :all_blank

  # Limit to 3 options
  validate :options_limit

  after_save :generate_variants_from_options!
  after_save :update_external_accounts

  def options_limit
    errors.add(:product_options, "can't have more than 3 options") if product_options.size > 3
  end

  # Generate all possible variant combinations from option values
  def all_variant_combinations
    return [] if product_options.empty?
    value_lists = product_options.map { |opt| opt.product_option_values.to_a }
    return [] if value_lists.any?(&:empty?)
    value_lists.first.product(*value_lists[1..])
  end

  # Generate variants for all combinations of option values
  def generate_variants_from_options!
    combos = all_variant_combinations
    return if combos.empty?
    combos.each do |combination|
      # Check if a variant with this exact set of option values exists
      next if variants.any? do |variant|
        vals = variant.variant_option_values.order(:product_option_id).map(&:product_option_value_id)
        vals == combination.map(&:id)
      end
      variant = variants.build
      combination.each_with_index do |value, idx|
        variant.variant_option_values.build(
          product_option: product_options[idx],
          product_option_value: value
        )
      end
    end
    save if changed?
  end

  private

  def update_external_accounts
    external_account_products.each(&:update_on_external_account)
  end
end
