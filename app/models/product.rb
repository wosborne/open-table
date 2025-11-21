class Product < ApplicationRecord
  TABLE_COLUMNS = attribute_names - [ "account_id", "description", "ebay_category_name", "ebay_category_id", "brand", "ebay_aspects", "created_at", "updated_at" ] + [ "in_stock" ]
  SEARCHABLE_ATTRIBUTES = [ "id", "name", "brand" ]

  belongs_to :account

  has_many :product_options, dependent: :destroy
  has_many :product_option_values, through: :product_options
  has_many :variants, dependent: :destroy
  has_many :external_account_products, dependent: :destroy
  has_many :inventory_units, through: :variants

  validates :name, presence: true, uniqueness: { scope: :account_id }

  accepts_nested_attributes_for :product_options, allow_destroy: true, reject_if: :all_blank

  # Allow eBay category assignment
  attr_accessor :ebay_category_data
  # after_save :update_external_accounts

  def in_stock
    inventory_units.in_stock.count
  end

  def item_aspects
    return [] unless ebay_category_id.present?
    ebay_aspects_data[:item_aspects] || []
  end

  def variation_aspects
    return [] unless ebay_category_id.present?
    ebay_aspects_data[:variation_aspects] || []
  end

  def brand_models_map
    return {} unless ebay_category_id.present?
    ebay_aspects_data[:brand_models_map] || {}
  end

  def saved_aspect_values
    ebay_aspects || {}
  end

  def aspect(name)
    ebay_aspects&.dig(name)
  end

  private

  def ebay_aspects_data
    @ebay_aspects_data ||= fetch_ebay_aspects_data
  end

  def fetch_ebay_aspects_data
    ebay_account = account.external_accounts.find_by(service_name: "ebay")
    return { item_aspects: [], variation_aspects: [], brand_models_map: {} } unless ebay_account

    begin
      ebay_category = EbayCategory.new(ebay_account)
      ebay_category.format_item_specifics_for_form(ebay_category_id)
    rescue => e
      Rails.logger.error "Failed to load eBay aspects for product #{id}: #{e.message}"
      { item_aspects: [], variation_aspects: [], brand_models_map: {} }
    end
  end

  def update_external_accounts
    external_account_products.find_each(&:sync_to_external_account)
  end
end
