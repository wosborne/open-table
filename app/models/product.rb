class Product < ApplicationRecord
  TABLE_COLUMNS = attribute_names - [ "account_id" ]
  has_many :variants, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }

  accepts_nested_attributes_for :variants, allow_destroy: true, reject_if: :all_blank
end
