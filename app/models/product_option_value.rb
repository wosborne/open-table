class ProductOptionValue < ApplicationRecord
  belongs_to :product_option

  validates :value, presence: true
  validates :value, uniqueness: { scope: :product_option_id }

  def external_id_for(external_account_product_id)
    external_ids && external_ids[external_account_product_id.to_s]
  end

  def set_external_id_for(external_account_product_id, value)
    self.external_ids ||= {}
    self.external_ids[external_account_product_id.to_s] = value
    save!
  end
end
