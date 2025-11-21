class Condition < ApplicationRecord
  EBAY_CONDITIONS = [
    "NEW", "LIKE_NEW", "NEW_OTHER", "NEW_WITH_DEFECTS",
    "CERTIFIED_REFURBISHED", "EXCELLENT_REFURBISHED", "VERY_GOOD_REFURBISHED",
    "GOOD_REFURBISHED", "SELLER_REFURBISHED",
    "USED_EXCELLENT", "USED_VERY_GOOD", "USED_GOOD", "USED_ACCEPTABLE",
    "FOR_PARTS_OR_NOT_WORKING", "PRE_OWNED_EXCELLENT", "PRE_OWNED_FAIR"
  ].freeze

  belongs_to :account
  has_many :variants, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :description, presence: true
  validates :ebay_condition, inclusion: { in: EBAY_CONDITIONS, allow_nil: true }

  scope :for_account, ->(account) { where(account: account) }

  def ebay_condition_display_name
    return nil unless ebay_condition.present?
    ebay_condition.downcase.titleize
  end
end
