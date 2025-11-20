class ProductOption < ApplicationRecord
  belongs_to :product
  has_many :product_option_values, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :product_id }

  accepts_nested_attributes_for :product_option_values, allow_destroy: true, reject_if: :all_blank

  def external_id_for(external_account_product_id)
    external_ids && external_ids[external_account_product_id.to_s]
  end

  def set_external_id_for(external_account_product_id, value)
    self.external_ids ||= {}
    self.external_ids[external_account_product_id.to_s] = value
    save!
  end
end
